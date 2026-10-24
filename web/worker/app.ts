import { Hono, type Context } from "hono";
import { requireAccess } from "./access";
import { activeSheet, LIVE_SHEET_ID, MODE_COOKIE, type ActiveSheet, type Env } from "./env";
import { GoogleAuthError } from "./google";
import { readWorkbook, SheetsApiError } from "./sheets";
import { fetchWoqod } from "./woqod";
import { refreshFromWoqod, writeMonthPrice, type PriceOutcome } from "./prices";
import { writeSettings, writeStations } from "./settings";
import { applyPlan } from "./writes";
import { parseEntries, parsePrices, parseSettings, SheetLayoutError } from "../shared/parse";
import { planStations, validateSettings, type SettingsPatch, type StationEdit } from "../shared/settings";
import type { DataResponse, Entry, PriceWriteResponse, SettingsWriteResponse, WriteResponse } from "../shared/types";
import { planAdd, planDelete, planEdit, PlanError, validateEntry, type EntryInput, type FieldErrors } from "../shared/writes";

type App = { Bindings: Env; Variables: { email: string; sheet: ActiveSheet } };
export const app = new Hono<App>();

// One JSON log line per failed or changing request (Workers Logs / `wrangler tail`). Reads that work stay quiet.
app.use("/api/*", async (c, next) => {
  const started = Date.now();
  await next();
  if (c.res.status >= 400 || c.req.method !== "GET") {
    const log = { event: "api", method: c.req.method, path: c.req.path, status: c.res.status, ms: Date.now() - started };
    (c.res.status >= 500 ? console.error : console.log)(JSON.stringify(log));
  }
});

app.use("/api/*", requireAccess);
app.use("/api/*", async (c, next) => {
  c.set("sheet", activeSheet(c.env, c.req.header("cookie")));
  await next();
  c.header("cache-control", "no-store");
});

// Writes must come from the app itself: same origin, JSON body. Together with Access's SameSite
// cookie this blocks cross-site form posts.
app.use("/api/*", async (c, next) => {
  if (c.req.method === "GET") return next();
  const origin = c.req.header("origin");
  if (origin && origin !== new URL(c.req.url).origin) return c.json({ error: "Cross-site request refused" }, 403);
  if (!c.req.header("content-type")?.startsWith("application/json")) return c.json({ error: "Expected JSON" }, 415);
  return next();
});

async function load(c: Context<App>, fresh: boolean): Promise<{ body: DataResponse; entries: Entry[] }> {
  const sheet = c.get("sheet");
  const wb = await readWorkbook(c.env, sheet.id, fresh);
  const entries = parseEntries(wb.data);
  return {
    entries,
    body: {
      email: c.get("email"),
      sheet: sheet.kind,
      canWrite: sheet.canWrite,
      testModeAvailable: sheet.testModeAvailable,
      sheetUrl: `https://docs.google.com/spreadsheets/d/${sheet.id}/edit`,
      fetchedAt: wb.fetchedAt,
      entries,
      prices: parsePrices(wb.prices),
      settings: parseSettings(wb.settings),
    },
  };
}

app.get("/api/me", (c) => c.json({ email: c.get("email") }));

app.get("/api/data", async (c) => c.json((await load(c, c.req.query("fresh") === "1")).body));

app.get("/api/woqod", async (c) => c.json(await fetchWoqod(c.req.query("fresh") === "1")));

/** Switch between the live sheet and the DEV copy (test mode). */
app.post("/api/mode", async (c) => {
  const { sheet } = await c.req.json<{ sheet: "live" | "dev" }>();
  const dev = sheet === "dev" && c.get("sheet").testModeAvailable;
  c.header("set-cookie", `${MODE_COOKIE}=${dev ? "dev" : "live"}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=${dev ? 86400 * 30 : 0}`);
  c.set("sheet", activeSheet(c.env, dev ? `${MODE_COOKIE}=dev` : ""));
  return c.json((await load(c, true)).body);
});

const qatarToday = () => new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Qatar" }).format(new Date());

/** Shared by add/edit/delete: fresh read, permission check, plan, atomic write, fresh read. */
async function write(
  c: Context<App>,
  build: (entries: Entry[], tankCapacityL: number) => { plan: ReturnType<typeof planAdd>; id: string; action: "add" | "edit" | "delete"; before: Entry | null; after: unknown },
) {
  const sheet = c.get("sheet");
  if (!sheet.canWrite) {
    return c.json({ error: "Saving to your live sheet isn't switched on yet. Use test mode (DEV sheet) to try it." }, 403);
  }
  const { entries, body } = await load(c, true);
  try {
    const { plan, id, action, before, after } = build(entries, body.settings.tankCapacityL);
    await applyPlan(c.env, sheet.id, plan, entries, { action, email: c.get("email"), entryId: id, before, after });
    const res: WriteResponse = { data: (await load(c, true)).body, result: { id, row: plan.row } };
    return c.json(res, action === "add" ? 201 : 200);
  } catch (e) {
    if (e instanceof PlanError) return c.json({ error: e.message, fields: e.fields, data: body }, 409);
    throw e;
  }
}

function checkInput(input: EntryInput, entries: Entry[], index: number, tankCapacityL: number) {
  const prev = index > 0 ? entries[index - 1]! : null;
  const next = index >= 0 && index < entries.length - 1 ? entries[index + 1]! : null;
  const errors: FieldErrors = validateEntry(input, { prev, next, today: qatarToday(), tankCapacityL });
  if (Object.keys(errors).length) throw new PlanError("Please fix the highlighted fields.", errors);
}

const newId = () => [...crypto.getRandomValues(new Uint8Array(4))].map((b) => b.toString(16).padStart(2, "0")).join("");

app.post("/api/entries", async (c) => {
  const { entry, lastIdSeen } = await c.req.json<{ entry: EntryInput; lastIdSeen: string | null }>();
  return write(c, (entries, tank) => {
    checkInput(entry, entries, entries.length, tank);
    const id = newId();
    return { plan: planAdd(entries, entry, id, lastIdSeen), id, action: "add", before: null, after: entry };
  });
});

app.put("/api/entries/:id", async (c) => {
  const id = c.req.param("id");
  const { entry, rowSeen } = await c.req.json<{ entry: EntryInput; rowSeen: number }>();
  return write(c, (entries, tank) => {
    const index = entries.findIndex((e) => e.id === id);
    if (index < 0) throw new PlanError("That fill-up is no longer in the sheet.");
    checkInput(entry, entries, index, tank);
    return { plan: planEdit(entries, id, entry, rowSeen), id, action: "edit", before: entries[index]!, after: entry };
  });
});

app.delete("/api/entries/:id", async (c) => {
  const id = c.req.param("id");
  const { rowSeen } = await c.req.json<{ rowSeen: number }>();
  return write(c, (entries) => ({
    plan: planDelete(entries, id, rowSeen),
    id,
    action: "delete",
    before: entries.find((e) => e.id === id) ?? null,
    after: null,
  }));
});

// ── Fuel prices ────────────────────────────────────────────────────────────

const LOCKED = "Saving to your live sheet isn't switched on. Use test mode (DEV sheet) to try it.";

async function priceResponse(c: Context<App>, run: () => Promise<PriceOutcome>) {
  if (!c.get("sheet").canWrite) return c.json({ error: LOCKED }, 403);
  const outcome = await run();
  const res: PriceWriteResponse = { data: (await load(c, true)).body, outcome };
  return c.json(res);
}

/** Months a price can be typed for: anything up to next month (WOQOD announces on the 1st). */
function checkMonth(month: string) {
  const today = qatarToday();
  const [y, m] = today.split("-").map(Number) as [number, number];
  const next = m === 12 ? `${y + 1}-01` : `${y}-${String(m + 1).padStart(2, "0")}`;
  return /^\d{4}-\d{2}$/.test(month) && month >= "2020-01" && month <= next;
}

app.post("/api/prices/refresh", (c) => priceResponse(c, () => refreshFromWoqod(c.env, c.get("sheet").id, c.get("email"))));

app.put("/api/prices/:month", async (c) => {
  const month = c.req.param("month");
  const { price } = await c.req.json<{ price: number }>();
  if (!checkMonth(month)) return c.json({ error: "Pick a month up to next month." }, 400);
  return priceResponse(c, () => writeMonthPrice(c.env, c.get("sheet").id, month, Number(price), "Manual", c.get("email")));
});

app.post("/api/prices/:month/unlock", (c) =>
  priceResponse(c, () => writeMonthPrice(c.env, c.get("sheet").id, c.req.param("month"), 0, "Sheet", c.get("email"))),
);

// ── Settings ───────────────────────────────────────────────────────────────

app.put("/api/settings", async (c) => {
  if (!c.get("sheet").canWrite) return c.json({ error: LOCKED }, 403);
  const { patch } = await c.req.json<{ patch: SettingsPatch }>();
  const { body } = await load(c, true);
  const clean: SettingsPatch = {};
  if (patch.theme !== undefined) clean.theme = String(patch.theme);
  if (patch.fuelGrade !== undefined) clean.fuelGrade = String(patch.fuelGrade);
  if (patch.tankCapacityL !== undefined) clean.tankCapacityL = Number(patch.tankCapacityL);
  if (patch.defaultMode !== undefined) clean.defaultMode = String(patch.defaultMode);
  const errors = validateSettings(clean, body.settings.modes);
  if (Object.keys(errors).length) return c.json({ error: Object.values(errors).join(" "), fields: errors }, 400);
  const message = await writeSettings(c.env, c.get("sheet").id, clean, c.get("email"));
  const res: SettingsWriteResponse = { data: (await load(c, true)).body, message };
  return c.json(res);
});

app.put("/api/stations", async (c) => {
  if (!c.get("sheet").canWrite) return c.json({ error: LOCKED }, 403);
  const { stations, renameInHistory } = await c.req.json<{ stations: StationEdit[]; renameInHistory: boolean }>();
  const { body, entries } = await load(c, true);
  let plan;
  try {
    plan = planStations(body.settings.stationList, stations, entries, !!renameInHistory);
  } catch (e) {
    return c.json({ error: e instanceof Error ? e.message : String(e), data: body }, 400);
  }
  const message = await writeStations(c.env, c.get("sheet").id, plan, body.settings.stationList, c.get("email"));
  const res: SettingsWriteResponse = { data: (await load(c, true)).body, message };
  return c.json(res);
});

// ── Error reporting ────────────────────────────────────────────────────────

/** Crashes and unhandled errors from the browser, so they show up in the Worker logs next to server errors. */
app.post("/api/client-error", async (c) => {
  const body = await c.req.json<Record<string, unknown>>().catch(() => ({}) as Record<string, unknown>);
  const text = (v: unknown, max: number) => (typeof v === "string" ? v.slice(0, max) : undefined);
  console.error(
    JSON.stringify({ event: "client_error", kind: text(body.kind, 40), message: text(body.message, 500), stack: text(body.stack, 2000), url: text(body.url, 200), ua: c.req.header("user-agent")?.slice(0, 200) }),
  );
  return c.body(null, 204);
});

app.notFound((c) => c.json({ error: "Not found" }, 404));

/** What the app shows for each kind of Google failure; `detail` carries Google's own message. */
function sheetsError(err: SheetsApiError): { error: string; status: 502 | 503 } {
  if (err.status === 429) return { error: "Google Sheets is busy (too many requests). Try again in a minute.", status: 503 };
  if (err.status === 403) return { error: "Google Sheets refused access. Check the sheet is still shared with the service account.", status: 502 };
  if (err.status === 404) return { error: "Google Sheets can't find the spreadsheet.", status: 502 };
  if (err.status >= 500) return { error: "Google Sheets had a problem. Try again.", status: 502 };
  return { error: "Google Sheets refused the request", status: 502 };
}

app.onError((err, c) => {
  const log = (kind: string) => console.error(JSON.stringify({ event: "api_error", kind, method: c.req.method, path: c.req.path, message: err.message.slice(0, 1000) }));
  if (err instanceof GoogleAuthError) {
    log("google_auth");
    return c.json({ error: "Google connection is not set up", detail: err.message }, 503);
  }
  if (err instanceof SheetLayoutError) {
    log("sheet_layout");
    return c.json({ error: "The sheet's layout changed", detail: err.message }, 409);
  }
  if (err instanceof SheetsApiError) {
    log(`sheets_${err.status}`);
    const { error, status } = sheetsError(err);
    if (err.status === 429) c.header("retry-after", String(err.retryAfter ?? 60));
    return c.json({ error, detail: err.message }, status);
  }
  log("unexpected");
  console.error(err);
  return c.json({ error: "Unexpected error" }, 500);
});

/**
 * Monthly price check (see "triggers" in wrangler.jsonc: 06:00 Qatar time on the 1st–5th).
 * Saves WOQOD's price for the new month to the live sheet and the DEV copy; manual prices are kept.
 */
export async function monthlyPriceCheck(env: Env) {
  const targets = [{ id: env.SHEET_ID, allowed: env.SHEET_ID !== LIVE_SHEET_ID || env.LIVE_WRITES === "true" }];
  if (env.DEV_SHEET_ID && env.DEV_SHEET_ID !== env.SHEET_ID) targets.push({ id: env.DEV_SHEET_ID, allowed: true });
  for (const t of targets) {
    const label = t.id === LIVE_SHEET_ID ? "live sheet" : "DEV sheet";
    if (!t.allowed) {
      console.log(JSON.stringify({ event: "price_check", sheet: label, ok: true, message: "skipped (live writes locked)" }));
      continue;
    }
    try {
      const r = await refreshFromWoqod(env, t.id, "monthly check");
      console.log(JSON.stringify({ event: "price_check", sheet: label, ok: true, message: r.message }));
    } catch (e) {
      console.error(JSON.stringify({ event: "price_check", sheet: label, ok: false, message: e instanceof Error ? e.message : String(e) }));
    }
  }
}
