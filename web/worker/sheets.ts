import { getAccessToken } from "./google";
import type { Env } from "./env";

export class SheetsApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

export type Cell = string | number | boolean | null;

const API = "https://sheets.googleapis.com/v4/spreadsheets";
const RAW = "valueRenderOption=UNFORMATTED_VALUE&dateTimeRenderOption=SERIAL_NUMBER";

async function call<T>(env: Env, url: string, init?: RequestInit): Promise<T> {
  const token = await getAccessToken(env.GOOGLE_SA_KEY);
  const res = await fetch(url, {
    ...init,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json", ...init?.headers },
  });
  if (!res.ok) throw new SheetsApiError(`Sheets request failed (${res.status}): ${await res.text()}`, res.status);
  return (await res.json()) as T;
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

const TTL_MS = 30_000;
const cache = new Map<string, { at: number; values: Cell[][][] }>();

/**
 * Data, Fuel Prices and Settings tabs in one read. Kept for 30 s per Worker instance so quick
 * navigation doesn't hit the Sheets quota; `fresh` skips the cache (refresh button, after a write).
 */
export async function readWorkbook(env: Env, sheetId: string, fresh = false) {
  const now = Date.now();
  let hit = cache.get(sheetId);
  if (fresh || !hit || now - hit.at > TTL_MS) {
    hit = { at: now, values: await batchGet(env, sheetId, [DATA_RANGE, PRICES_RANGE, SETTINGS_RANGE]) };
    cache.set(sheetId, hit);
  }
  const [data = [], prices = [], settings = []] = hit.values;
  return { data, prices, settings, fetchedAt: new Date(hit.at).toISOString() };
}
