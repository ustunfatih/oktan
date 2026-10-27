import { exportPKCS8, generateKeyPair } from "jose";
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { dataTab } from "../shared/__fixtures__/data-tab";
import { JOBS_HEADERS, PLAN_HEADERS } from "../shared/maintenance";
import { isoToSerial } from "../shared/writes";
import type { Env } from "./env";
import { LIVE_SHEET_ID } from "./env";

// End-to-end through the Hono routes, with Google faked at the fetch level: token endpoint,
// values:batchGet, spreadsheet metadata and batchUpdate.

const DEV = "dev-sheet-id";
const ME = "me@example.com";
const settingsTab = [
  ["Setting", "Value", "", "", "Stations", "Archived", "Modes"],
  ["Theme", "auto", "", "", "Pearl", false, "Eco"],
  ["Tank capacity (L)", 47, "", "", "Dafna", false, "Normal"],
  ["", "", "", "", "", "", "Sport"],
];
const pricesTab = [["Month", "Price", "Source"], [46296, 2.1, "WOQOD"]];

/** Minimal stand-in for the Workers Cache API (`caches.default`), keyed by URL. */
function fakeEdgeCache() {
  const store = new Map<string, string>();
  return {
    default: {
      match: async (req: Request) => (store.has(req.url) ? new Response(store.get(req.url)) : undefined),
      put: async (req: Request, res: Response) => void store.set(req.url, await res.text()),
      delete: async (req: Request) => store.delete(req.url),
    },
  };
}

type Reply = { status: number; body?: unknown; headers?: Record<string, string> };
type Cell = string | number | boolean | null;

let saKey: string;
let app: typeof import("./app").app;
let google: ReturnType<typeof fakeGoogle>;

function fakeGoogle() {
  const reads: Reply[] = [];
  const writes: Reply[] = [];
  const batchUpdates: { requests: { [k: string]: unknown }[] }[] = [];
  const calls: string[] = [];
  /** Rows of the optional service tabs; null means the tab doesn't exist yet. */
  const tabs = { jobs: null as Cell[][] | null, plan: null as Cell[][] | null };
  const reply = (r: Reply) => new Response(JSON.stringify(r.body ?? {}), { status: r.status, headers: r.headers });
  const valuesFor = (range: string): Cell[][] => {
    if (range.startsWith("Data!")) return dataTab;
    if (range.startsWith("'Fuel Prices'")) return pricesTab;
    if (range.startsWith("Settings!")) return settingsTab;
    if (range.startsWith("Maintenance!")) return tabs.jobs ?? [];
    if (range.startsWith("'Service plan'")) return tabs.plan ?? [];
    throw new Error(`Unexpected range ${range}`);
  };

  const fetch = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.startsWith("https://oauth2.googleapis.com/token")) return reply({ status: 200, body: { access_token: "tok", expires_in: 3600 } });
    if (!url.startsWith("https://sheets.googleapis.com/")) throw new Error(`Unexpected fetch ${url}`);
    if (url.includes(":batchUpdate")) {
      calls.push("batchUpdate");
      const queued = writes.shift();
      if (queued) return reply(queued);
      batchUpdates.push(JSON.parse(String(init?.body)));
      return reply({ status: 200, body: {} });
    }
    if (url.includes("values:batchGet")) {
      calls.push("batchGet");
      const queued = reads.shift();
      if (queued) return reply(queued);
      const ranges = new URL(url).searchParams.getAll("ranges");
      return reply({ status: 200, body: { valueRanges: ranges.map((r) => ({ values: valuesFor(r) })) } });
    }
    calls.push("meta");
    const sheets = [
      { properties: { sheetId: 0, title: "Data" }, tables: [{ tableId: "gas", range: { sheetId: 0, endRowIndex: 40 } }] },
      { properties: { sheetId: 6000, title: "App_Log" } },
    ];
    if (tabs.jobs) sheets.push({ properties: { sheetId: 7000, title: "Maintenance" }, tables: undefined as never });
    if (tabs.plan) sheets.push({ properties: { sheetId: 7001, title: "Service plan" }, tables: undefined as never });
    return reply({ status: 200, body: { sheets: sheets.map((x) => (x.tables === undefined ? { properties: x.properties } : x)) } });
  });
  return { fetch, reads, writes, batchUpdates, calls, tabs };
}

const env = (over: Partial<Env> = {}): Env => ({
  ACCESS_TEAM_DOMAIN: "team.cloudflareaccess.com",
  ACCESS_AUD: "aud",
  ALLOWED_EMAIL: ME,
  SHEET_ID: DEV,
  GOOGLE_SA_KEY: saKey,
  DEV_EMAIL: ME,
  ...over,
});

const get = (path: string, e = env(), host = "http://localhost") => app.request(`${host}${path}`, {}, e);
const send = (method: string, path: string, body: unknown, e = env(), headers: Record<string, string> = {}) =>
  app.request(`http://localhost${path}`, { method, headers: { "content-type": "application/json", ...headers }, body: JSON.stringify(body) }, e);

const newEntry = { date: "2026-10-21", odometer: 9200, liters: 40, pricePerLiter: 2.1, totalCost: 84, full: true, mode: "Eco", station: "Pearl" };

beforeAll(async () => {
  const { privateKey } = await generateKeyPair("RS256", { extractable: true });
  saKey = JSON.stringify({ client_email: "sa@test.iam.gserviceaccount.com", private_key: await exportPKCS8(privateKey) });
});

beforeEach(async () => {
  // Fresh modules each test: the workbook and token caches live at module level.
  vi.resetModules();
  google = fakeGoogle();
  vi.stubGlobal("fetch", google.fetch);
  vi.stubGlobal("caches", fakeEdgeCache());
  vi.spyOn(console, "log").mockImplementation(() => {});
  vi.spyOn(console, "warn").mockImplementation(() => {});
  vi.spyOn(console, "error").mockImplementation(() => {});
  ({ app } = await import("./app"));
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("sign-in", () => {
  it("refuses requests without an Access token", async () => {
    const res = await get("/api/data", env({ DEV_EMAIL: undefined }));
    expect(res.status).toBe(401);
    expect(google.fetch).not.toHaveBeenCalled();
  });

  it("honours the local dev identity on localhost only", async () => {
    const res = await get("/api/data", env(), "https://oktan.ustunfatih.com");
    expect(res.status).toBe(401);
  });
});

describe("GET /api/data", () => {
  it("returns the parsed sheet", async () => {
    const res = await get("/api/data");
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toBe("no-store");
    const body = (await res.json()) as { entries: unknown[]; sheet: string; canWrite: boolean; email: string; settings: { stations: string[] } };
    expect(body.entries).toHaveLength(dataTab.length - 1);
    expect(body).toMatchObject({ sheet: "dev", canWrite: true, email: ME });
    expect(body.settings.stations).toEqual(["Pearl", "Dafna"]);
  });

  it("serves a second read from the 30 s cache", async () => {
    await get("/api/data");
    await get("/api/data");
    expect(google.calls.filter((c) => c === "batchGet")).toHaveLength(1);
  });

  it("marks the live sheet read-only until LIVE_WRITES is on", async () => {
    const res = await get("/api/data", env({ SHEET_ID: LIVE_SHEET_ID }));
    expect(((await res.json()) as { sheet: string; canWrite: boolean })).toMatchObject({ sheet: "live", canWrite: false });
  });
});

describe("write guards", () => {
  it("refuses non-JSON writes", async () => {
    const res = await app.request("http://localhost/api/entries", { method: "POST", body: "x", headers: { "content-type": "text/plain" } }, env());
    expect(res.status).toBe(415);
  });

  it("refuses cross-site writes", async () => {
    const res = await send("POST", "/api/entries", { entry: newEntry, lastIdSeen: "0b96f058" }, env(), { origin: "https://evil.example" });
    expect(res.status).toBe(403);
    expect(google.calls).not.toContain("batchUpdate");
  });

  it("keeps the live sheet locked without LIVE_WRITES", async () => {
    const res = await send("POST", "/api/entries", { entry: newEntry, lastIdSeen: "0b96f058" }, env({ SHEET_ID: LIVE_SHEET_ID }));
    expect(res.status).toBe(403);
    expect(google.calls).not.toContain("batchUpdate");
  });
});

describe("POST /api/entries", () => {
  it("adds a fill-up in one atomic batchUpdate with an App_Log row", async () => {
    const res = await send("POST", "/api/entries", { entry: newEntry, lastIdSeen: "0b96f058" });
    expect(res.status).toBe(201);
    expect(google.batchUpdates).toHaveLength(1);
    const kinds = google.batchUpdates[0]!.requests.map((r) => Object.keys(r)[0]);
    expect(kinds).toContain("updateCells");
    expect(kinds.at(-1)).toBe("appendCells");
    const log = JSON.stringify(google.batchUpdates[0]!.requests.at(-1));
    expect(log).toContain('"stringValue":"add"');
    expect(log).toContain(ME);
  });

  it("returns field errors without writing", async () => {
    const res = await send("POST", "/api/entries", { entry: { ...newEntry, odometer: 100 }, lastIdSeen: "0b96f058" });
    expect(res.status).toBe(409);
    expect(((await res.json()) as { fields: Record<string, string> }).fields.odometer).toMatch(/more than the previous/);
    expect(google.calls).not.toContain("batchUpdate");
  });

  it("refuses when someone added a row since the page loaded", async () => {
    const res = await send("POST", "/api/entries", { entry: newEntry, lastIdSeen: "fbbda3a9" });
    expect(res.status).toBe(409);
    expect(google.calls).not.toContain("batchUpdate");
  });
});

describe("Google quota and failures", () => {
  it("retries a 429 and then succeeds", async () => {
    google.reads.push({ status: 429, headers: { "retry-after": "0" } });
    const res = await get("/api/data");
    expect(res.status).toBe(200);
    expect(google.calls.filter((c) => c === "batchGet")).toHaveLength(2);
  });

  it("gives up after three retries with a clear 503", async () => {
    for (let i = 0; i < 4; i++) google.reads.push({ status: 429, headers: { "retry-after": "0" } });
    const res = await get("/api/data");
    expect(res.status).toBe(503);
    expect(res.headers.get("retry-after")).toBe("0");
    expect(((await res.json()) as { error: string }).error).toMatch(/busy/);
    expect(google.calls.filter((c) => c === "batchGet")).toHaveLength(4);
  });

  it("retries a read that hit a Google server error", async () => {
    google.reads.push({ status: 503, headers: { "retry-after": "0" } });
    expect((await get("/api/data")).status).toBe(200);
  });

  it("never retries a write that hit a server error (it may have landed)", async () => {
    google.writes.push({ status: 500, headers: { "retry-after": "0" } });
    const res = await send("POST", "/api/entries", { entry: newEntry, lastIdSeen: "0b96f058" });
    expect(res.status).toBe(502);
    expect(google.calls.filter((c) => c === "batchUpdate")).toHaveLength(1);
  });

  it("explains a lost share", async () => {
    google.reads.push({ status: 403, body: { error: { message: "The caller does not have permission" } } });
    const res = await get("/api/data");
    expect(res.status).toBe(502);
    expect(((await res.json()) as { error: string }).error).toMatch(/shared with the service account/);
  });

  it("drops a rejected token and retries once", async () => {
    google.reads.push({ status: 401 });
    expect((await get("/api/data")).status).toBe(200);
    expect(google.fetch.mock.calls.filter(([u]) => String(u).includes("oauth2")).length).toBe(2);
  });

  it("reports a missing service account key as setup, not a crash", async () => {
    const res = await get("/api/data", env({ GOOGLE_SA_KEY: undefined }));
    expect(res.status).toBe(503);
    expect(((await res.json()) as { error: string }).error).toMatch(/not set up/);
  });

  it("logs every failure as one JSON line", async () => {
    google.reads.push({ status: 404 });
    await get("/api/data");
    const lines = vi.mocked(console.error).mock.calls.map(([l]) => JSON.parse(String(l)));
    expect(lines).toContainEqual(expect.objectContaining({ event: "api_error", kind: "sheets_404", path: "/api/data" }));
    expect(lines).toContainEqual(expect.objectContaining({ event: "api", status: 502 }));
  });
});

describe("POST /api/client-error", () => {
  it("logs browser crashes, trimmed", async () => {
    const res = await send("POST", "/api/client-error", { kind: "render", message: "x".repeat(2000), url: "/log" });
    expect(res.status).toBe(204);
    const line = JSON.parse(String(vi.mocked(console.error).mock.calls[0]![0]));
    expect(line).toMatchObject({ event: "client_error", kind: "render", url: "/log" });
    expect(line.message).toHaveLength(500);
  });
});

describe("monthly price check", () => {
  it("skips the live sheet while writes are locked", async () => {
    const { monthlyPriceCheck } = await import("./app");
    await monthlyPriceCheck(env({ SHEET_ID: LIVE_SHEET_ID }));
    const line = JSON.parse(String(vi.mocked(console.log).mock.calls[0]![0]));
    expect(line).toMatchObject({ event: "price_check", sheet: "live sheet", message: "skipped (live writes locked)" });
    expect(google.fetch).not.toHaveBeenCalled();
  });
});

describe("service (maintenance)", () => {
  const job = (over: Record<string, unknown> = {}) => ({
    date: "2026-10-01",
    odometer: 8800,
    category: "Oil and filter",
    description: "Oil and filter",
    costQar: 150,
    workshop: "Al Meera",
    nextDueKm: null,
    nextDueDate: null,
    notes: "",
    ...over,
  });
  const existing = [JOBS_HEADERS as unknown as Cell[], [isoToSerial("2026-09-01"), 8500, "Oil and filter", "Oil", 150, "Al Meera", null, null, null, "j1"]];

  it("adds a job, creating the Maintenance tab on the first save", async () => {
    const res = await send("POST", "/api/service", { job: job(), rowCountSeen: 0 });
    expect(res.status).toBe(201);
    const body = (await res.json()) as { result: { id: string; row: number } };
    expect(body.result).toMatchObject({ row: 2 });
    const requests = google.batchUpdates[0]!.requests;
    expect(requests).toContainEqual(expect.objectContaining({ addSheet: expect.objectContaining({ properties: expect.objectContaining({ sheetId: 7000, title: "Maintenance" }) }) }));
    expect(JSON.stringify(requests)).toContain('"stringValue":"Oil and filter"');
    expect(JSON.stringify(requests.at(-1))).toContain('"stringValue":"service add"');
  });

  it("adds below the last row when the tab exists", async () => {
    google.tabs.jobs = existing;
    const res = await send("POST", "/api/service", { job: job({ date: "2026-10-05" }), rowCountSeen: 2 });
    expect(res.status).toBe(201);
    expect(google.batchUpdates[0]!.requests[0]).toMatchObject({ updateCells: { range: { sheetId: 7000, startRowIndex: 2, endRowIndex: 3 } } });
  });

  it("refuses an add when rows were added since the page loaded", async () => {
    google.tabs.jobs = existing;
    const res = await send("POST", "/api/service", { job: job(), rowCountSeen: 1 });
    expect(res.status).toBe(409);
    expect(((await res.json()) as { error: string }).error).toMatch(/changed/);
    expect(google.calls).not.toContain("batchUpdate");
  });

  it("refuses an odometer far above the last reading and names the field", async () => {
    const res = await send("POST", "/api/service", { job: job({ odometer: 99999 }), rowCountSeen: 0 });
    expect(res.status).toBe(409);
    expect(((await res.json()) as { fields: Record<string, string> }).fields.odometer).toMatch(/2,000 km/);
  });

  it("edits a job in place", async () => {
    google.tabs.jobs = existing;
    const res = await send("PUT", "/api/service/j1", { job: job({ costQar: 200 }), rowSeen: 2 });
    expect(res.status).toBe(200);
    expect(google.batchUpdates[0]!.requests[0]).toMatchObject({ updateCells: { range: { sheetId: 7000, startRowIndex: 1, endRowIndex: 2 } } });
    expect(JSON.stringify(google.batchUpdates[0]!.requests[0])).toContain('"numberValue":200');
  });

  it("refuses an edit when the job has moved", async () => {
    google.tabs.jobs = existing;
    const res = await send("PUT", "/api/service/j1", { job: job(), rowSeen: 7 });
    expect(res.status).toBe(409);
  });

  it("deletes a job's row and logs it", async () => {
    google.tabs.jobs = existing;
    const res = await send("DELETE", "/api/service/j1", { rowSeen: 2 });
    expect(res.status).toBe(200);
    expect(google.batchUpdates[0]!.requests[0]).toEqual({ deleteDimension: { range: { sheetId: 7000, dimension: "ROWS", startIndex: 1, endIndex: 2 } } });
    expect(JSON.stringify(google.batchUpdates[0]!.requests.at(-1))).toContain('"stringValue":"service delete"');
  });

  it("reads the jobs, what's due and the default plan on the data response", async () => {
    google.tabs.jobs = existing;
    const body = (await (await get("/api/data")).json()) as { service: { jobs: { id: string }[]; due: { category: string; status: string }[]; planIsDefault: boolean; plan: unknown[]; highestOdometer: number } };
    expect(body.service.jobs.map((j) => j.id)).toEqual(["j1"]);
    expect(body.service.due[0]).toMatchObject({ category: "Oil and filter" });
    expect(body.service.planIsDefault).toBe(true);
    expect(body.service.plan).toHaveLength(9);
    expect(body.service.highestOdometer).toBe(8774); // the last fill-up is higher than the job at 8,500 km
  });

  it("saves the plan and creates its tab", async () => {
    const res = await send("PUT", "/api/service-plan", { plan: [{ category: "Oil and filter", everyKm: 10000, everyMonths: 12 }] });
    expect(res.status).toBe(200);
    const requests = google.batchUpdates[0]!.requests;
    expect(requests).toContainEqual(expect.objectContaining({ addSheet: expect.objectContaining({ properties: expect.objectContaining({ sheetId: 7001, title: "Service plan" }) }) }));
    expect(PLAN_HEADERS).toContain("Every km");
  });

  it("refuses a plan with a duplicate category", async () => {
    const res = await send("PUT", "/api/service-plan", {
      plan: [
        { category: "Tyres", everyKm: 40000, everyMonths: null },
        { category: "tyres", everyKm: 30000, everyMonths: null },
      ],
    });
    expect(res.status).toBe(400);
    expect(google.calls).not.toContain("batchUpdate");
  });

  it("keeps service writes locked on the live sheet", async () => {
    const res = await send("POST", "/api/service", { job: job(), rowCountSeen: 0 }, env({ SHEET_ID: LIVE_SHEET_ID }));
    expect(res.status).toBe(403);
    expect(google.calls).not.toContain("batchUpdate");
  });
});
