import { importJWK, SignJWT } from "jose";
import type { Env } from "./env";

/**
 * Web push, end to end: the browser gives us a subscription (an endpoint plus two keys); we encrypt the
 * message to that browser (RFC 8291, "aes128gcm") and send it to the push service with a VAPID header
 * that proves who is sending (RFC 8292). Written against WebCrypto, which Workers provide.
 */

export interface PushSubscription {
  endpoint: string;
  keys: { p256dh: string; auth: string };
}

export class PushNotConfigured extends Error {}

const enc = new TextEncoder();

export const toB64u = (u: Uint8Array) => btoa(String.fromCharCode(...u)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
export const fromB64u = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));

function concat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
}

async function hkdf(salt: Uint8Array, ikm: Uint8Array, info: Uint8Array, bytes: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  return new Uint8Array(await crypto.subtle.deriveBits({ name: "HKDF", hash: "SHA-256", salt, info }, key, bytes * 8));
}

/**
 * Encrypts one message for one subscription (RFC 8291). `salt` and `ephemeral` are only passed by tests,
 * which use them to check the output against known values; real sends make fresh ones.
 */
export async function encryptPayload(
  plaintext: Uint8Array,
  uaPublic: Uint8Array,
  authSecret: Uint8Array,
  opts: { salt?: Uint8Array; ephemeral?: CryptoKeyPair } = {},
): Promise<Uint8Array> {
  const ephemeral =
    opts.ephemeral ?? ((await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"])) as CryptoKeyPair);
  const asPublic = new Uint8Array((await crypto.subtle.exportKey("raw", ephemeral.publicKey as CryptoKey)) as ArrayBuffer);
  const uaKey = await crypto.subtle.importKey("raw", uaPublic, { name: "ECDH", namedCurve: "P-256" }, false, []);
  // The runtime reads this as `public`; the type definitions spell it `$public`.
  const ecdh = { name: "ECDH", public: uaKey } as unknown as SubtleCryptoDeriveKeyAlgorithm;
  const shared = new Uint8Array(await crypto.subtle.deriveBits(ecdh, ephemeral.privateKey as CryptoKey, 256));

  const ikm = await hkdf(authSecret, shared, concat(enc.encode("WebPush: info\0"), uaPublic, asPublic), 32);
  const salt = opts.salt ?? crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(salt, ikm, enc.encode("Content-Encoding: aes128gcm\0"), 16);
  const nonce = await hkdf(salt, ikm, enc.encode("Content-Encoding: nonce\0"), 12);

  const key = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  // One record, so the padding delimiter is 0x02 (the last record) followed by nothing.
  const sealed = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, concat(plaintext, Uint8Array.of(2))));
  const recordSize = new Uint8Array([0, 0, 16, 0]); // 4096, big-endian
  return concat(salt, recordSize, Uint8Array.of(asPublic.length), asPublic, sealed);
}

async function vapidKey(env: Env) {
  if (!env.VAPID_PRIVATE_JWK || !env.VAPID_PUBLIC_KEY) throw new PushNotConfigured("VAPID keys are not set up");
  return importJWK(JSON.parse(env.VAPID_PRIVATE_JWK), "ES256");
}

/** Sends one message. Returns the push service's status: 201 is delivered; 404 or 410 means the subscription is gone. */
export async function sendPush(env: Env, sub: PushSubscription, message: { title: string; body: string; url?: string; tag?: string }): Promise<number> {
  const key = await vapidKey(env);
  const origin = new URL(sub.endpoint).origin;
  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", typ: "JWT" })
    .setAudience(origin)
    .setSubject(env.VAPID_SUBJECT ?? "mailto:ustunfa@gmail.com")
    .setExpirationTime("12h")
    .sign(key);
  const body = await encryptPayload(enc.encode(JSON.stringify(message)), fromB64u(sub.keys.p256dh), fromB64u(sub.keys.auth));
  const res = await fetch(sub.endpoint, {
    method: "POST",
    headers: {
      TTL: "86400",
      Urgency: "normal",
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      Authorization: `vapid t=${jwt}, k=${env.VAPID_PUBLIC_KEY}`,
    },
    body,
  });
  return res.status;
}
