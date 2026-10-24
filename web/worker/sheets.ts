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

type Cell = string | number | boolean | null;

/** Reads a range with raw values: numbers stay numbers, dates come back as serial numbers. */
export async function getValues(env: Env, range: string): Promise<Cell[][]> {
  const token = await getAccessToken(env.GOOGLE_SA_KEY);
  const url =
    `https://sheets.googleapis.com/v4/spreadsheets/${env.SHEET_ID}/values/${encodeURIComponent(range)}` +
    `?valueRenderOption=UNFORMATTED_VALUE&dateTimeRenderOption=SERIAL_NUMBER`;
  const res = await fetch(url, { headers: { authorization: `Bearer ${token}` } });
  if (!res.ok) throw new SheetsApiError(`Sheets read failed (${res.status}): ${await res.text()}`, res.status);
  const body = (await res.json()) as { values?: Cell[][] };
  return body.values ?? [];
}
