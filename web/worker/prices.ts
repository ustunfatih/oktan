import { parseSettings } from "../shared/parse";
import { decidePriceWrite, monthLabel, parsePriceRows, woqodForGrade, type PriceSource } from "../shared/prices";
import { isoToSerial } from "../shared/writes";
import type { Env } from "./env";
import { batchGet, batchUpdate, getMeta, PRICES_RANGE, SETTINGS_RANGE } from "./sheets";
import { fetchWoqod } from "./woqod";
import { appLogRequests, cell } from "./writes";

export type PriceOutcome = { written: boolean; message: string; month?: string; price?: number };

/**
 * Writes one month's price to the Fuel Prices tab (C = price, D = source) as a single batchUpdate,
 * appending the month row if it isn't listed yet, and logs it to App_Log.
 */
export async function writeMonthPrice(env: Env, spreadsheetId: string, month: string, price: number, source: PriceSource | "Sheet", by: string): Promise<PriceOutcome> {
  const [values = []] = await batchGet(env, spreadsheetId, [PRICES_RANGE]);
  const rows = parsePriceRows(values);
  // "Sheet" is only used to unlock a manual price: keep the value, drop the lock.
  const decision =
    source === "Sheet"
      ? (() => {
          const r = rows.find((x) => x.month === month);
          return r && r.source === "Manual" ? ({ action: "write", row: r.row, append: false, before: r } as const) : ({ action: "skip", reason: `${monthLabel(month)} isn't locked.` } as const);
        })()
      : decidePriceWrite(rows, month, price, source);
  if (decision.action === "skip") return { written: false, message: decision.reason, month };

  const meta = await getMeta(env, spreadsheetId);
  const tab = meta.tabs.find((t) => t.title === "Fuel Prices");
  if (!tab) return { written: false, message: "The sheet has no Fuel Prices tab." };
  const range = (c0: number, c1: number) => ({ sheetId: tab.sheetId, startRowIndex: decision.row - 1, endRowIndex: decision.row, startColumnIndex: c0, endColumnIndex: c1 });
  const value = source === "Sheet" ? (decision.before?.price ?? null) : price;

  const requests: unknown[] = [];
  if (decision.append) {
    requests.push({
      updateCells: {
        range: range(1, 2),
        rows: [{ values: [{ ...cell(isoToSerial(`${month}-01`)), userEnteredFormat: { numberFormat: { type: "DATE", pattern: "MMM-YY" } } }] }],
        fields: "userEnteredValue,userEnteredFormat.numberFormat",
      },
    });
  }
  requests.push({
    updateCells: {
      range: range(2, 4),
      rows: [{ values: [{ ...cell(value), userEnteredFormat: { numberFormat: { type: "NUMBER", pattern: "#,##0.00" } } }, cell(source)] }],
      fields: "userEnteredValue,userEnteredFormat.numberFormat",
    },
  });
  requests.push(...appLogRequests(meta, ["price", by, month, JSON.stringify(decision.before), JSON.stringify({ price: value, source })]));
  await batchUpdate(env, spreadsheetId, requests);

  const verb = source === "Sheet" ? "Unlocked" : source === "Manual" ? "Saved (locked)" : "Saved from WOQOD";
  return { written: true, message: `${verb}: ${monthLabel(month)} at QAR ${(value ?? 0).toFixed(2)}.`, month, price: value ?? undefined };
}

/** Fetch WOQOD's current price for the sheet's fuel grade and save it, unless the month is locked. */
export async function refreshFromWoqod(env: Env, spreadsheetId: string, by: string): Promise<PriceOutcome> {
  const woqod = await fetchWoqod(true);
  if (!woqod.ok) return { written: false, message: woqod.error };
  const [settingsValues = []] = await batchGet(env, spreadsheetId, [SETTINGS_RANGE]);
  const grade = parseSettings(settingsValues).fuelGrade;
  const mine = woqodForGrade(woqod.prices, grade);
  if (!mine) return { written: false, message: `WOQOD has no price for ${grade}.` };
  return writeMonthPrice(env, spreadsheetId, mine.month, mine.price, "WOQOD", by);
}
