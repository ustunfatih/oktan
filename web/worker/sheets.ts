import { clearAccessToken, getAccessToken } from "./google";
import type { Env } from "./env";
import { JOBS_TAB, PLAN_TAB } from "../shared/maintenance";

export class SheetsApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    /** Seconds Google asked us to wait (429), when it said. */
    readonly retryAfter?: number,
  ) {
    super(message);
  }
}

export type Cell = string | number | boolean | null;

const API = "https://sheets.googleapis.com/v4/spreadsheets";
const RAW = "valueRenderOption=UNFORMATTED_VALUE&dateTimeRenderOption=SERIAL_NUMBER";

/** Waits between attempts; Google's quota is per minute, so a few seconds usually clears a burst. */
export const RETRY_DELAYS_MS = [500, 1500, 4000];
const MAX_WAIT_MS = 8000;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function retryAfterSeconds(res: Response): number | undefined {
  const v = Number(res.headers.get("retry-after"));
  return Number.isFinite(v) && v >= 0 ? v : undefined;
}

/**
 * One Sheets API call with retries. A 429 (quota) is always safe to retry, because Google refused it
 * before doing anything. Server errors (5xx) are retried for reads only: a write that failed with a 5xx
 * may or may not have landed, so it is reported instead of risking a double add.
 * A 401 means the cached access token went bad; it is dropped and the call retried once.
 */
async function call<T>(env: Env, url: string, init?: RequestInit): Promise<T> {
  const isRead = !init?.method || init.method === "GET";
  let refreshedToken = false;
  for (let attempt = 0; ; attempt++) {
    const token = await getAccessToken(env.GOOGLE_SA_KEY);
    const res = await fetch(url, {
      ...init,
      headers: { authorization: `Bearer ${token}`, "content-type": "application/json", ...init?.headers },
    });
    if (res.ok) return (await res.json()) as T;

    const text = await res.text();
    if (res.status === 401 && !refreshedToken) {
      refreshedToken = true;
      clearAccessToken();
      continue;
    }
    const after = retryAfterSeconds(res);
    const retryable = res.status === 429 || (isRead && res.status >= 500);
    const delay = after !== undefined ? after * 1000 : RETRY_DELAYS_MS[attempt];
    if (retryable && attempt < RETRY_DELAYS_MS.length && delay !== undefined && delay <= MAX_WAIT_MS) {
      console.warn(JSON.stringify({ event: "sheets_retry", status: res.status, attempt: attempt + 1, delayMs: delay }));
      await sleep(delay);
      continue;
    }
    throw new SheetsApiError(`Sheets request failed (${res.status}): ${text.slice(0, 500)}`, res.status, after);
  }
}

/** Reads several ranges in one request, with raw values (numbers stay numbers, dates are serials). */
export async function batchGet(env: Env, sheetId: string, ranges: string[]): Promise<Cell[][][]> {
  const qs = ranges.map((r) => `ranges=${encodeURIComponent(r)}`).join("&");
  const body = await call<{ valueRanges?: { values?: Cell[][] }[] }>(env, `${API}/${sheetId}/values:batchGet?${qs}&${RAW}`);
  return ranges.map((_, i) => body.valueRanges?.[i]?.values ?? []);
}

export interface SheetMeta {
  tabs: { sheetId: number; title: string }[];
  tables: { tableId: string; sheetId: number; endRowIndex: number }[];
}

export async function getMeta(env: Env, sheetId: string): Promise<SheetMeta> {
  const fields = "sheets(properties(sheetId,title),tables(tableId,range))";
  const body = await call<{
    sheets: { properties: { sheetId: number; title: string }; tables?: { tableId: string; range: { sheetId?: number; endRowIndex: number } }[] }[];
  }>(env, `${API}/${sheetId}?fields=${encodeURIComponent(fields)}`);
  return {
    tabs: body.sheets.map((s) => s.properties),
    tables: body.sheets.flatMap((s) =>
      (s.tables ?? []).map((t) => ({ tableId: t.tableId, sheetId: t.range.sheetId ?? s.properties.sheetId, endRowIndex: t.range.endRowIndex })),
    ),
  };
}

export async function batchUpdate(env: Env, sheetId: string, requests: unknown[]): Promise<void> {
  await call(env, `${API}/${sheetId}:batchUpdate`, { method: "POST", body: JSON.stringify({ requests }) });
}

export const DATA_RANGE = "Data!A1:P";
export const PRICES_RANGE = "'Fuel Prices'!B2:D";
export const SETTINGS_RANGE = "Settings!A1:G";
export const JOBS_RANGE = JOBS_TAB + "!A1:J";
export const PLAN_RANGE = "'" + PLAN_TAB + "'!A1:C";

/** How long a read of the workbook is reused. Quick navigation hits the cache; writes always re-read. */
const CACHE_SECONDS = 30;

export interface Workbook {
  data: Cell[][];
  prices: Cell[][];
  settings: Cell[][];
  /** Maintenance tab, header included; empty until the tab exists. */
  jobs: Cell[][];
  /** Service plan tab, header included; empty until the tab exists. */
  plan: Cell[][];
  /** Whether each optional tab exists (the app shows defaults when it doesn't). */
  hasJobsTab: boolean;
  hasPlanTab: boolean;
  fetchedAt: string;
}

/**
 * The Cache API is shared by every Worker instance in the same data centre, unlike a variable in memory,
 * so one read serves all the requests that arrive in that window. Absent in unit tests, where reads go
 * straight to Google.
 */
const edgeCache = () => (globalThis as { caches?: { default?: Cache } }).caches?.default;
const cacheKey = (sheetId: string) => new Request(`https://cache.oktan.internal/workbook/${sheetId}`);
const metaKey = (sheetId: string) => new Request(`https://cache.oktan.internal/tabs/${sheetId}`);

/** Which tabs exist, cached for five minutes. Creating a tab clears it (see `forgetTabs`). */
export async function tabsOf(env: Env, sheetId: string, fresh = false): Promise<SheetMeta> {
  const cache = edgeCache();
  if (cache && !fresh) {
    const hit = await cache.match(metaKey(sheetId));
    if (hit) return (await hit.json()) as SheetMeta;
  }
  const meta = await getMeta(env, sheetId);
  if (cache) await cache.put(metaKey(sheetId), new Response(JSON.stringify(meta), { headers: { "cache-control": "max-age=300" } }));
  return meta;
}

export async function forgetTabs(sheetId: string) {
  await edgeCache()?.delete(metaKey(sheetId));
}

/**
 * Data, Fuel Prices, Settings and the optional service tabs in one read. `fresh` skips the cache (refresh
 * button, page loads after a write); every successful read refreshes it.
 */
export async function readWorkbook(env: Env, sheetId: string, fresh = false): Promise<Workbook> {
  const cache = edgeCache();
  if (cache && !fresh) {
    const hit = await cache.match(cacheKey(sheetId));
    if (hit) return (await hit.json()) as Workbook;
  }
  const tabs = await tabsOf(env, sheetId, fresh);
  const hasJobsTab = tabs.tabs.some((t) => t.title === JOBS_TAB);
  const hasPlanTab = tabs.tabs.some((t) => t.title === PLAN_TAB);
  const ranges = [DATA_RANGE, PRICES_RANGE, SETTINGS_RANGE];
  if (hasJobsTab) ranges.push(JOBS_RANGE);
  if (hasPlanTab) ranges.push(PLAN_RANGE);
  const [data = [], prices = [], settings = [], jobs = [], plan = []] = await batchGet(env, sheetId, ranges);
  const wb: Workbook = {
    data,
    prices,
    settings,
    jobs: hasJobsTab ? jobs : [],
    plan: hasPlanTab ? plan : [],
    hasJobsTab,
    hasPlanTab,
    fetchedAt: new Date().toISOString(),
  };
  if (cache) {
    await cache.put(cacheKey(sheetId), new Response(JSON.stringify(wb), { headers: { "cache-control": `max-age=${CACHE_SECONDS}` } }));
  }
  return wb;
}
