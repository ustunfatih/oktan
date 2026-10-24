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
