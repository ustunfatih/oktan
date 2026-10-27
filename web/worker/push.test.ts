import { exportPKCS8, generateKeyPair, jwtVerify, importJWK } from "jose";
import { beforeAll, beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import { dataTab } from "../shared/__fixtures__/data-tab";
import { isoToSerial } from "../shared/writes";
import type { Env } from "./env";
import { encryptPayload, fromB64u, sendPush, toB64u } from "./push";
import { addDays, addSubscription, countSubscriptions, dailyCheck, getPrefs, KEY_NOTICE_DAYS } from "./reminders";

// Web push checks: the message format (RFC 8291) round-trips through a decrypt written from the spec,
// the VAPID header verifies against the public key, and the daily check sends one reminder per fill-up.

const enc = new TextEncoder();
const dec = new TextDecoder();

let vapid: { privateJwk: string; publicKey: string; publicRaw: Uint8Array };
let saKey: string;

/** A browser's side of a subscription: its key pair and its auth secret. */
async function browser() {
  const pair = (await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"])) as CryptoKeyPair;
  const pub = new Uint8Array(await crypto.subtle.exportKey("raw", pair.publicKey));
  const auth = crypto.getRandomValues(new Uint8Array(16));
  return { pair, pub, auth, p256dh: toB64u(pub), authB64: toB64u(auth) };
}

async function hkdf(salt: Uint8Array, ikm: Uint8Array, info: Uint8Array, bytes: number) {
  const key = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  return new Uint8Array(await crypto.subtle.deriveBits({ name: "HKDF", hash: "SHA-256", salt, info }, key, bytes * 8));
}

/** Decrypts an aes128gcm body the way a browser does, from RFC 8291. */
async function decryptBody(body: Uint8Array, ua: Awaited<ReturnType<typeof browser>>) {
  const salt = body.slice(0, 16);
  const rs = new DataView(body.buffer, body.byteOffset + 16, 4).getUint32(0);
  const idLen = body[20]!;
  const asPublic = body.slice(21, 21 + idLen);
  const sealed = body.slice(21 + idLen);
  expect(rs).toBe(4096);
  expect(idLen).toBe(65);

  const asKey = await crypto.subtle.importKey("raw", asPublic, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const shared = new Uint8Array(
    await crypto.subtle.deriveBits({ name: "ECDH", public: asKey } as unknown as SubtleCryptoDeriveKeyAlgorithm, ua.pair.privateKey, 256),
  );
  const ikm = await hkdf(ua.auth, shared, concat(enc.encode("WebPush: info\0"), ua.pub, asPublic), 32);
  const cek = await hkdf(salt, ikm, enc.encode("Content-Encoding: aes128gcm\0"), 16);
  const nonce = await hkdf(salt, ikm, enc.encode("Content-Encoding: nonce\0"), 12);
  const key = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["decrypt"]);
  const padded = new Uint8Array(await crypto.subtle.decrypt({ name: "AES-GCM", iv: nonce }, key, sealed));
  expect(padded[padded.length - 1]).toBe(2); // the last-record delimiter
  return dec.decode(padded.slice(0, -1));
}

function concat(...parts: Uint8Array[]) {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
}

const env = (over: Partial<Env> = {}): Env =>
  ({
    VAPID_PRIVATE_JWK: vapid.privateJwk,
    VAPID_PUBLIC_KEY: vapid.publicKey,
    VAPID_SUBJECT: "mailto:ustunfa@gmail.com",
    ACCESS_TEAM_DOMAIN: "team.cloudflareaccess.com",
    ACCESS_AUD: "aud",
    ALLOWED_EMAIL: "ustunfa@gmail.com",
    SHEET_ID: "sheet-live",
    GOOGLE_SA_KEY: saKey,
    ...over,
  }) as Env;

/** In-memory KV with the parts of the API the Worker uses. */
function fakeKv() {
  const store = new Map<string, string>();
  return {
    store,
    get: async (k: string, type?: string) => {
      const v = store.get(k);
      if (v === undefined) return null;
      return type === "json" ? JSON.parse(v) : v;
    },
    put: async (k: string, v: string) => void store.set(k, v),
    delete: async (k: string) => void store.delete(k),
    list: async ({ prefix }: { prefix: string }) => ({ keys: [...store.keys()].filter((k) => k.startsWith(prefix)).map((name) => ({ name })) }),
  };
}

beforeAll(async () => {
  const pair = await generateKeyPair("ES256", { extractable: true });
  const jwk = await crypto.subtle.exportKey("jwk", (pair as unknown as { privateKey: CryptoKey }).privateKey);
  const pubJwk = await crypto.subtle.exportKey("jwk", (pair as unknown as { publicKey: CryptoKey }).publicKey);
  const publicRaw = fromB64u(pubJwk.x!).length === 32 ? concat(Uint8Array.of(4), fromB64u(pubJwk.x!), fromB64u(pubJwk.y!)) : new Uint8Array();
  vapid = { privateJwk: JSON.stringify({ kty: "EC", crv: "P-256", d: jwk.d, x: jwk.x, y: jwk.y }), publicKey: toB64u(publicRaw), publicRaw };
  const sa = await generateKeyPair("RS256", { extractable: true });
  saKey = JSON.stringify({ client_email: "sa@test.iam.gserviceaccount.com", private_key: await exportPKCS8(sa.privateKey) });
});

describe("encryptPayload", () => {
  it("produces a body a browser can decrypt, with the spec's header layout", async () => {
    const ua = await browser();
    const body = await encryptPayload(enc.encode(JSON.stringify({ title: "Hi" })), ua.pub, ua.auth);
    expect(await decryptBody(body, ua)).toBe(JSON.stringify({ title: "Hi" }));
  });

  it("uses fresh randomness for every message", async () => {
    const ua = await browser();
    const a = await encryptPayload(enc.encode("same"), ua.pub, ua.auth);
    const b = await encryptPayload(enc.encode("same"), ua.pub, ua.auth);
    expect(toB64u(a)).not.toBe(toB64u(b));
  });

  it("is refused by a different browser", async () => {
    const ua = await browser();
    const other = await browser();
    const body = await encryptPayload(enc.encode("private"), ua.pub, ua.auth);
    await expect(decryptBody(body, other)).rejects.toThrow();
  });
});

describe("sendPush", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("posts an encrypted message with a VAPID header that verifies", async () => {
    const ua = await browser();
    const sent: { url: string; headers: Record<string, string>; body: Uint8Array }[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string, init: RequestInit) => {
        sent.push({ url, headers: init.headers as Record<string, string>, body: new Uint8Array(init.body as ArrayBuffer) });
        return new Response(null, { status: 201 });
      }),
    );
    const status = await sendPush(env(), { endpoint: "https://push.example.test/abc", keys: { p256dh: ua.p256dh, auth: ua.authB64 } }, { title: "Time for a fill-up?", body: "x" });
    expect(status).toBe(201);
    const [msg] = sent;
    expect(msg!.url).toBe("https://push.example.test/abc");
    expect(msg!.headers["Content-Encoding"]).toBe("aes128gcm");
    expect(msg!.headers.TTL).toBe("86400");
    const auth = msg!.headers.Authorization!;
    expect(auth).toMatch(/^vapid t=[\w.-]+, k=/);
    const token = auth.match(/t=([^,]+)/)![1]!;
    const pub = await importJWK({ kty: "EC", crv: "P-256", x: toB64u(vapid.publicRaw.slice(1, 33)), y: toB64u(vapid.publicRaw.slice(33, 65)) }, "ES256");
    const { payload } = await jwtVerify(token, pub, { audience: "https://push.example.test" });
    expect(payload.sub).toBe("mailto:ustunfa@gmail.com");
    expect(await decryptBody(msg!.body, ua)).toBe(JSON.stringify({ title: "Time for a fill-up?", body: "x" }));
  });

  it("says so clearly when the keys aren't set", async () => {
    await expect(sendPush(env({ VAPID_PRIVATE_JWK: undefined }), { endpoint: "https://push.example.test/x", keys: { p256dh: "AAAA", auth: "AAAA" } }, { title: "t", body: "b" })).rejects.toThrow(/VAPID/);
  });
});

describe("dailyCheck", () => {
  const lastDate = "2026-10-21"; // the fixture's last fill-up
  let pushes: string[];

  beforeEach(() => {
    pushes = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string, init?: RequestInit) => {
        if (url.startsWith("https://oauth2.googleapis.com/token")) return Response.json({ access_token: "tok", expires_in: 3600 });
        if (url.startsWith("https://push.example.test/")) {
          pushes.push(url);
          return new Response(null, { status: 201 });
        }
        if (url.includes("values:batchGet")) {
          const ranges = new URL(url).searchParams.getAll("ranges");
          const v = (r: string) => (r.startsWith("Data!") ? dataTab : r.startsWith("'Fuel") ? [["Month", "Price", "Source"]] : [["Setting", "Value"]]);
          return Response.json({ valueRanges: ranges.map((r) => ({ values: v(r) })) });
        }
        return Response.json({ sheets: [{ properties: { sheetId: 0, title: "Data" } }] });
      }),
    );
  });
  afterEach(() => vi.unstubAllGlobals());

  it("sends one reminder once the gap is long enough, and not again for the same fill-up", async () => {
    const kv = fakeKv();
    const e = env({ PUSH: kv as unknown as KVNamespace });
    await addSubscription(kv as unknown as KVNamespace, { endpoint: "https://push.example.test/phone", keys: { p256dh: (await browser()).p256dh, auth: "AAAA" } });

    const tooSoon = await dailyCheck(e, addDays(lastDate, 3));
    expect(tooSoon).toEqual({});
    expect(pushes).toHaveLength(0);

    const due = await dailyCheck(e, addDays(lastDate, 12));
    expect(due).toMatchObject({ reminder: { sent: 1 } });
    expect(pushes).toHaveLength(1);

    const again = await dailyCheck(e, addDays(lastDate, 13));
    expect(again).toEqual({});
    expect(pushes).toHaveLength(1);
  });

  it("sends the key-rotation notice once, close to a year after the key was made", async () => {
    const kv = fakeKv();
    const created = "2026-10-24";
    const e = env({ PUSH: kv as unknown as KVNamespace, KEY_CREATED_ON: created });
    await addSubscription(kv as unknown as KVNamespace, { endpoint: "https://push.example.test/phone", keys: { p256dh: (await browser()).p256dh, auth: "AAAA" } });
    // This fill-up has already been reminded about, so only the key notice can fire below.
    kv.store.set("prefs", JSON.stringify({ afterDays: 10, notifiedFor: "0b96f058" }));
    expect(await dailyCheck(e, addDays(created, KEY_NOTICE_DAYS - 1))).toEqual({});
    expect(await dailyCheck(e, addDays(created, KEY_NOTICE_DAYS))).toMatchObject({ keyNotice: { sent: 1 } });
    expect(await dailyCheck(e, addDays(created, KEY_NOTICE_DAYS + 1))).toEqual({});
  });

  it("forgets a subscription the push service says is gone", async () => {
    const kv = fakeKv();
    const e = env({ PUSH: kv as unknown as KVNamespace });
    await addSubscription(kv as unknown as KVNamespace, { endpoint: "https://push.example.test/old", keys: { p256dh: (await browser()).p256dh, auth: "AAAA" } });
    vi.stubGlobal("fetch", vi.fn(async (url: string) => (url.includes("oauth2") ? Response.json({ access_token: "t", expires_in: 3600 }) : url.includes("values:") ? Response.json({ valueRanges: [{ values: dataTab }, { values: [] }, { values: [] }] }) : url.includes("push.example") ? new Response(null, { status: 410 }) : Response.json({ sheets: [{ properties: { sheetId: 0, title: "Data" } }] }))));
    await dailyCheck(e, addDays(lastDate, 12));
    expect(await countSubscriptions(kv as unknown as KVNamespace)).toBe(0);
  });

  it("keeps the default reminder gap of 10 days", async () => {
    expect((await getPrefs(fakeKv() as unknown as KVNamespace)).afterDays).toBe(10);
  });
});

describe("dates for the checks", () => {
  it("counts whole days and rolls over months", () => {
    expect(addDays("2026-10-28", 5)).toBe("2026-11-02");
    expect(isoToSerial("2026-10-21")).toBe(46316);
  });
});
