import { monthRange } from "./dashboard";
import type { Entry, MonthPrice } from "./types";

export type RangeKey = "3m" | "6m" | "12m" | "ytd" | "all";

export interface Filters {
  range: RangeKey;
  /** null = all modes */
  mode: string | null;
  /** null = all stations; "" = fill-ups with no station recorded */
  station: string | null;
}

export const ALL: Filters = { range: "all", mode: null, station: null };

/** First date (YYYY-MM-DD) included by a range, or null for "all". */
export function rangeStart(range: RangeKey, today: string): string | null {
  if (range === "all") return null;
  if (range === "ytd") return `${today.slice(0, 4)}-01-01`;
  const months = range === "3m" ? 3 : range === "6m" ? 6 : 12;
  const d = new Date(`${today}T00:00:00Z`);
  d.setUTCMonth(d.getUTCMonth() - months);
  return d.toISOString().slice(0, 10);
}

export function applyFilters(entries: Entry[], f: Filters, today: string): Entry[] {
  const from = rangeStart(f.range, today);
  return entries.filter(
    (e) =>
      (!from || e.date >= from) &&
      (f.mode === null || e.mode === f.mode) &&
      (f.station === null || (e.station ?? "") === f.station),
  );
}

type Closed = Entry & { distanceKm: number; usedFuelL: number };
export const closedTrips = (entries: Entry[]): Closed[] =>
  entries.filter((e): e is Closed => e.distanceKm !== null && e.distanceKm > 0 && e.usedFuelL !== null);

/** Distance-weighted L/100 km and QAR/km over a set of trips. */
function efficiency(trips: Closed[]) {
  const km = trips.reduce((s, e) => s + e.distanceKm, 0);
  const used = trips.reduce((s, e) => s + e.usedFuelL, 0);
  const cost = trips.reduce((s, e) => s + e.usedFuelL * (e.pricePerLiter ?? 0), 0);
  return { km, litersPer100Km: km ? (100 * used) / km : null, costPerKm: km ? cost / km : null };
}

export interface GroupStats {
  key: string;
  fills: number;
  trips: number;
  km: number;
  liters: number;
  spend: number;
  litersPer100Km: number | null;
  costPerKm: number | null;
}

function groupBy(entries: Entry[], keyOf: (e: Entry) => string, order: string[] = []): GroupStats[] {
  const keys = [...new Set([...order, ...entries.map(keyOf)])];
  return keys
    .map((key) => {
      const list = entries.filter((e) => keyOf(e) === key);
      const eff = efficiency(closedTrips(list));
      return {
        key,
        fills: list.length,
        trips: closedTrips(list).length,
        km: eff.km,
        liters: list.reduce((s, e) => s + e.liters, 0),
        spend: list.reduce((s, e) => s + (e.totalCost ?? 0), 0),
        litersPer100Km: eff.litersPer100Km,
        costPerKm: eff.costPerKm,
      };
    })
    .filter((g) => g.fills > 0);
}

/** One row per drive mode, best (lowest L/100 km) first. */
export const byMode = (entries: Entry[], modes: string[]) =>
  groupBy(entries, (e) => e.mode ?? "Unknown", modes).sort(
    (a, b) => (a.litersPer100Km ?? Infinity) - (b.litersPer100Km ?? Infinity),
  );

/** One row per station, highest spend first. Fill-ups without a station are grouped under "". */
export const byStation = (entries: Entry[]) =>
  groupBy(entries, (e) => e.station ?? "").sort((a, b) => b.spend - a.spend);

/** Weighted L/100 km for trips starting in the given calendar months (1–12). */
export function seasonEfficiency(entries: Entry[], months: number[]) {
  const trips = closedTrips(entries).filter((e) => months.includes(Number(e.date.slice(5, 7))));
  return { trips: trips.length, ...efficiency(trips) };
}

export interface HeatCell {
  month: string;
  litersPer100Km: number | null;
  trips: number;
}

/** Year rows × 12 month columns of weighted L/100 km (by the month a trip started). */
export function efficiencyHeat(entries: Entry[]): { year: string; cells: HeatCell[] }[] {
  const trips = closedTrips(entries);
  const years = [...new Set(entries.map((e) => e.date.slice(0, 4)))].sort();
  return years.map((year) => ({
    year,
    cells: Array.from({ length: 12 }, (_, i) => {
      const month = `${year}-${String(i + 1).padStart(2, "0")}`;
      const inMonth = trips.filter((e) => e.date.startsWith(month));
      return { month, trips: inMonth.length, litersPer100Km: efficiency(inMonth).litersPer100Km };
    }),
  }));
}

/** Number of tanks per 0.5 L/100 km band, from the lowest to the highest band seen. */
export function distribution(entries: Entry[], width = 0.5) {
  const values = closedTrips(entries).map((e) => e.litersPer100Km).filter((v): v is number => v !== null);
  if (!values.length) return [];
  const lo = Math.floor(Math.min(...values) / width) * width;
  const hi = Math.floor(Math.max(...values) / width) * width;
  const bins: { from: number; to: number; count: number }[] = [];
  for (let from = lo; from <= hi + 1e-9; from += width) {
    const f = Math.round(from * 100) / 100;
    bins.push({ from: f, to: Math.round((f + width) * 100) / 100, count: values.filter((v) => v >= f - 1e-9 && v < f + width - 1e-9).length });
  }
  return bins;
}

/** Running total of spend, one point per fill-up. */
export function cumulativeSpend(entries: Entry[]) {
  let total = 0;
  return entries.map((e) => ({ id: e.id, date: e.date, spend: e.totalCost ?? 0, total: (total += e.totalCost ?? 0) }));
}

/** Monthly prices that have a value, limited to the months a filtered range covers. */
export function priceHistory(prices: MonthPrice[], from: string | null, today: string) {
  const end = today.slice(0, 7);
  return prices.filter((p): p is MonthPrice & { price: number } => p.price !== null && p.month <= end && (!from || p.month >= from.slice(0, 7)));
}

export interface Records {
  bestTank: Closed | null;
  worstTank: Closed | null;
  longestTank: Closed | null;
  biggestFill: Entry | null;
  priciestMonth: { month: string; spend: number; fills: number } | null;
  cheapestPrice: (MonthPrice & { price: number }) | null;
}

export function records(entries: Entry[], prices: MonthPrice[]): Records {
  const trips = closedTrips(entries).filter((e) => e.litersPer100Km !== null);
  const pick = <T>(list: T[], score: (x: T) => number) =>
    list.reduce<T | null>((best, x) => (best === null || score(x) > score(best) ? x : best), null);
  const months =
    entries.length > 0
      ? monthRange(entries[0]!.date.slice(0, 7), entries.at(-1)!.date.slice(0, 7)).map((month) => {
          const list = entries.filter((e) => e.date.startsWith(month));
          return { month, fills: list.length, spend: list.reduce((s, e) => s + (e.totalCost ?? 0), 0) };
        })
      : [];
  const priced = prices.filter((p): p is MonthPrice & { price: number } => p.price !== null);
  return {
    bestTank: pick(trips, (e) => -e.litersPer100Km!),
    worstTank: pick(trips, (e) => e.litersPer100Km!),
    longestTank: pick(trips, (e) => e.distanceKm),
    biggestFill: pick(entries, (e) => e.liters),
    priciestMonth: pick(months.filter((m) => m.fills > 0), (m) => m.spend),
    cheapestPrice: pick(priced, (p) => -p.price),
  };
}

/** Average price actually paid per litre. */
export const avgPricePaid = (entries: Entry[]) => {
  const liters = entries.reduce((s, e) => s + e.liters, 0);
  return liters ? entries.reduce((s, e) => s + (e.totalCost ?? 0), 0) / liters : null;
};
