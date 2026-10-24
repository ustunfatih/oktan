import { lastClosedEntry, latestEntry, summarize } from "./metrics";
import type { Entry, MonthPrice, Settings, Summary } from "./types";

export interface TrendPoint {
  id: string;
  date: string;
  value: number;
  km: number;
  station: string | null;
  mode: string | null;
}

export interface MonthTotal {
  /** YYYY-MM */
  month: string;
  spend: number;
  liters: number;
  fills: number;
}

export interface DashboardModel {
  summary: Summary;
  latest: Entry | null;
  lastClosed: Entry | null;
  /** Distance-weighted L/100 km over the last five completed trips. */
  last5LitersPer100Km: number | null;
  kmPerLiter: number | null;
  /** What a full tank would cover at the lifetime average. */
  fullTankRangeKm: number | null;
  trend: TrendPoint[];
  best: TrendPoint | null;
  worst: TrendPoint | null;
  year: { spend: number; fills: number };
  month: { spend: number; fills: number };
  monthly: MonthTotal[];
  nextFill: { date: string; everyDays: number } | null;
  currentPrice: MonthPrice | null;
  previousPrice: MonthPrice | null;
  recent: Entry[];
}

const DAY_MS = 86_400_000;
const toDay = (iso: string) => Date.parse(`${iso}T00:00:00Z`) / DAY_MS;
const fromDay = (day: number) => new Date(day * DAY_MS).toISOString().slice(0, 10);

/** Every month from `from` to `to` inclusive, as YYYY-MM. */
export function monthRange(from: string, to: string): string[] {
  const out: string[] = [];
  let [y, m] = from.split("-").map(Number) as [number, number];
  const [ty, tm] = to.split("-").map(Number) as [number, number];
  while (y < ty || (y === ty && m <= tm)) {
    out.push(`${y}-${String(m).padStart(2, "0")}`);
    m += 1;
    if (m > 12) {
      m = 1;
      y += 1;
    }
  }
  return out;
}

const previousMonth = (month: string) => {
  const [y, m] = month.split("-").map(Number) as [number, number];
  return m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, "0")}`;
};

const weightedL100 = (trend: TrendPoint[]) => {
  const km = trend.reduce((s, p) => s + p.km, 0);
  return km > 0 ? trend.reduce((s, p) => s + p.value * p.km, 0) / km : null;
};

/**
 * Everything the Dashboard shows, computed from the sheet's rows.
 * @param today the viewer's date (Qatar time) as YYYY-MM-DD
 */
export function buildDashboard(entries: Entry[], prices: MonthPrice[], settings: Settings, today: string): DashboardModel {
  const summary = summarize(entries);
  const trend: TrendPoint[] = entries
    .filter((e) => e.litersPer100Km !== null && e.distanceKm !== null && e.distanceKm > 0)
    .map((e) => ({
      id: e.id,
      date: e.date,
      value: e.litersPer100Km!,
      km: e.distanceKm!,
      station: e.station,
      mode: e.mode,
    }));

  const thisYear = today.slice(0, 4);
  const thisMonth = today.slice(0, 7);
  const sumOf = (list: Entry[]) => ({ spend: list.reduce((s, e) => s + (e.totalCost ?? 0), 0), fills: list.length });

  const first = entries[0];
  const last = latestEntry(entries);
  const monthly: MonthTotal[] = first
    ? monthRange(first.date.slice(0, 7), thisMonth > last!.date.slice(0, 7) ? thisMonth : last!.date.slice(0, 7)).map(
        (month) => {
          const inMonth = entries.filter((e) => e.date.startsWith(month));
          return { month, ...sumOf(inMonth), liters: inMonth.reduce((s, e) => s + e.liters, 0) };
        },
      )
    : [];

  let nextFill: DashboardModel["nextFill"] = null;
  if (first && last && entries.length > 1) {
    const everyDays = Math.round((toDay(last.date) - toDay(first.date)) / (entries.length - 1));
    nextFill = { date: fromDay(toDay(last.date) + everyDays), everyDays };
  }

  const byValue = [...trend].sort((a, b) => a.value - b.value);
  const priceFor = (month: string) => prices.find((p) => p.month === month && p.price !== null) ?? null;

  return {
    summary,
    latest: last,
    lastClosed: lastClosedEntry(entries),
    last5LitersPer100Km: weightedL100(trend.slice(-5)),
    kmPerLiter: summary.litersPer100Km ? 100 / summary.litersPer100Km : null,
    fullTankRangeKm: summary.litersPer100Km ? (settings.tankCapacityL / summary.litersPer100Km) * 100 : null,
    trend,
    best: byValue[0] ?? null,
    worst: byValue.at(-1) ?? null,
    year: sumOf(entries.filter((e) => e.date.startsWith(thisYear))),
    month: sumOf(entries.filter((e) => e.date.startsWith(thisMonth))),
    monthly,
    nextFill,
    currentPrice: priceFor(thisMonth),
    previousPrice: priceFor(previousMonth(thisMonth)),
    recent: entries.slice(-5).reverse(),
  };
}
