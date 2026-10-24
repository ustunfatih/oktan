import type { MonthPrice, WoqodPrice } from "./types";

const GRADE: Record<string, RegExp> = { "super 95": /95/, "premium 91": /91/, diesel: /diesel/i };

/** The WOQOD row for the grade chosen in Settings (Super 95 unless set otherwise). */
export const woqodForGrade = (prices: WoqodPrice[], fuelGrade: string) =>
  prices.find((p) => (GRADE[fuelGrade.toLowerCase()] ?? /95/).test(p.grade)) ?? null;

export interface SuggestedPrice {
  price: number;
  /** Where it came from, for the hint under the field. */
  source: string;
  month: string;
}

/**
 * Price to pre-fill for a fill-up on `date`: that month's price from the Fuel Prices tab, else
 * WOQOD's current price if it is for that month, else the most recent earlier price.
 */
export function priceForDate(date: string, prices: MonthPrice[], woqod: WoqodPrice | null): SuggestedPrice | null {
  const month = date.slice(0, 7);
  const exact = prices.find((p) => p.month === month && p.price !== null);
  if (exact) return { price: exact.price!, source: exact.source === "WOQOD" ? "WOQOD" : "Fuel Prices tab", month };
  if (woqod && woqod.month === month) return { price: woqod.price, source: "WOQOD", month };
  const earlier = prices.filter((p) => p.month < month && p.price !== null).at(-1);
  return earlier ? { price: earlier.price!, source: `last known (${earlier.month})`, month: earlier.month } : null;
}

/** A Fuel Prices row with its sheet row number (the block starts at B2; row 2 is the header). */
export interface PriceRow {
  row: number;
  month: string;
  price: number | null;
  source: string | null;
}

export function parsePriceRows(values: (string | number | boolean | null | undefined)[][]): PriceRow[] {
  return values.slice(1).flatMap((r, i) => {
    if (typeof r[0] !== "number") return [];
    const iso = new Date(Math.round((r[0] - 25569) * 86_400_000)).toISOString();
    const price = typeof r[1] === "number" ? r[1] : null;
    const source = typeof r[2] === "string" && r[2].trim() ? r[2].trim() : null;
    return [{ row: i + 3, month: iso.slice(0, 7), price, source }];
  });
}

export type PriceSource = "WOQOD" | "Manual";

const MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
/** "2026-11" → "November 2026" */
export const monthLabel = (month: string) => `${MONTH_NAMES[Number(month.slice(5, 7)) - 1] ?? month} ${month.slice(0, 4)}`;

export type PriceDecision =
  | { action: "write"; row: number; append: boolean; before: PriceRow | null }
  | { action: "skip"; reason: string };

/**
 * Whether (and where) to write a month's price.
 * A Manual price is locked: WOQOD never overwrites it. Unchanged values are not rewritten,
 * so the monthly check doesn't fill App_Log with no-ops.
 */
export function decidePriceWrite(rows: PriceRow[], month: string, price: number, source: PriceSource): PriceDecision {
  if (!/^\d{4}-\d{2}$/.test(month)) return { action: "skip", reason: "Invalid month." };
  if (!Number.isFinite(price) || price < 0.5 || price > 5) return { action: "skip", reason: "Prices in Qatar are between QAR 0.50 and 5.00." };
  const existing = rows.find((r) => r.month === month) ?? null;
  if (existing) {
    if (source === "WOQOD" && existing.source === "Manual") {
      return { action: "skip", reason: `${monthLabel(month)} has a manual price (QAR ${existing.price?.toFixed(2) ?? "—"}), which WOQOD doesn't overwrite.` };
    }
    if (existing.price !== null && Math.abs(existing.price - price) < 0.0005 && existing.source === source) {
      return { action: "skip", reason: `${monthLabel(month)} is already QAR ${price.toFixed(2)} (${source}).` };
    }
    return { action: "write", row: existing.row, append: false, before: existing };
  }
  const last = rows.at(-1);
  if (last && month < last.month) return { action: "skip", reason: `${monthLabel(month)} is missing from the Fuel Prices list; add it in the sheet first.` };
  return { action: "write", row: last ? last.row + 1 : 3, append: true, before: null };
}
