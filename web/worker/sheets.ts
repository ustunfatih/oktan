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

const RAW = "valueRenderOption=UNFORMATTED_VALUE&dateTimeRenderOption=SERIAL_NUMBER";

/** Reads several ranges in one request, with raw values (numbers stay numbers, dates are serials). */
export async function batchGet(env: Env, ranges: string[]): Promise<Cell[][][]> {
  const token = await getAccessToken(env.GOOGLE_SA_KEY);
  const qs = ranges.map((r) => `ranges=${encodeURIComponent(r)}`).join("&");
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${env.SHEET_ID}/values:batchGet?${qs}&${RAW}`;
  const res = await fetch(url, { headers: { authorization: `Bearer ${token}` } });
  if (!res.ok) throw new SheetsApiError(`Sheets read failed (${res.status}): ${await res.text()}`, res.status);
  const body = (await res.json()) as { valueRanges?: { values?: Cell[][] }[] };
  return ranges.map((_, i) => body.valueRanges?.[i]?.values ?? []);
}

export const DATA_RANGE = "Data!A1:P";
export const PRICES_RANGE = "'Fuel Prices'!B2:D";
export const SETTINGS_RANGE = "Settings!A1:G";

const TTL_MS = 30_000;
let cache: { sheetId: string; at: number; values: Cell[][][] } | null = null;

/**
 * Data, Fuel Prices and Settings tabs in one read. Kept for 30 s per Worker instance so quick
 * navigation doesn't hit the Sheets quota; `fresh` skips the cache (pull-to-refresh, after a write).
 */
export async function readWorkbook(env: Env, fresh = false) {
  const now = Date.now();
  if (fresh || !cache || cache.sheetId !== env.SHEET_ID || now - cache.at > TTL_MS) {
    cache = { sheetId: env.SHEET_ID, at: now, values: await batchGet(env, [DATA_RANGE, PRICES_RANGE, SETTINGS_RANGE]) };
  }
  const [data = [], prices = [], settings = []] = cache.values;
  return { data, prices, settings, fetchedAt: new Date(cache.at).toISOString() };
}
