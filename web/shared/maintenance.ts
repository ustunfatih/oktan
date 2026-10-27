import { serialToIsoDate } from "./parse";
import type { Cell } from "./parse";

/** Service, repair and parts history: the `Maintenance` tab, plus intervals in `Service plan`. */

export const JOBS_TAB = "Maintenance";
export const PLAN_TAB = "Service plan";
export const JOBS_HEADERS = ["Date", "Odometer km", "Category", "Description", "Cost QAR", "Workshop", "Next due km", "Next due date", "Notes", "ID"] as const;
export const PLAN_HEADERS = ["Category", "Every km", "Every months"] as const;

export interface ServiceJob {
  id: string;
  /** Sheet row (1-based). */
  row: number;
  date: string;
  odometer: number;
  category: string;
  description: string;
  costQar: number | null;
  workshop: string;
  nextDueKm: number | null;
  nextDueDate: string | null;
  notes: string;
}

export interface PlanItem {
  category: string;
  everyKm: number | null;
  everyMonths: number | null;
}

/**
 * Starting intervals. These are generic placeholders: check them against your car's service book and change
 * them in the Plan section (or in the Service plan tab) to match.
 */
export const DEFAULT_PLAN: PlanItem[] = [
  { category: "Oil and filter", everyKm: 10000, everyMonths: 12 },
  { category: "Air filter", everyKm: 20000, everyMonths: null },
  { category: "Tyres", everyKm: 40000, everyMonths: null },
  { category: "Brakes", everyKm: 30000, everyMonths: 24 },
  { category: "Battery", everyKm: null, everyMonths: 36 },
  { category: "Coolant", everyKm: 60000, everyMonths: 24 },
  { category: "Spark plugs", everyKm: 60000, everyMonths: null },
  { category: "Inspection", everyKm: null, everyMonths: 12 },
  { category: "Other", everyKm: null, everyMonths: null },
];

export const DUE_SOON_KM = 1000;
export const DUE_SOON_DAYS = 30;
export const MAX_ODOMETER_JUMP_KM = 2000;

export type DueStatus = "overdue" | "soon" | "ok";

export interface DueItem {
  category: string;
  status: DueStatus;
  /** The job the countdown starts from. */
  last: ServiceJob;
  dueKm: number | null;
  kmLeft: number | null;
  dueDate: string | null;
  daysLeft: number | null;
}

const ISO = /^\d{4}-\d{2}-\d{2}$/;
const num = (v: Cell): number | null => (typeof v === "number" && Number.isFinite(v) ? v : null);
const text = (v: Cell): string => String(v ?? "").trim();

/** A date cell: a Sheets serial number, or text typed as YYYY-MM-DD. */
function isoOf(v: Cell): string | null {
  if (typeof v === "number" && Number.isFinite(v)) return serialToIsoDate(v);
  const s = text(v);
  return ISO.test(s) && !Number.isNaN(Date.parse(`${s}T00:00:00Z`)) ? s : null;
}

/**
 * Jobs from the Maintenance tab's values (header row first). A row without a valid date or category is skipped,
 * and counted in `skipped` so the app can say so instead of hiding it.
 */
export function parseJobs(values: Cell[][]): { jobs: ServiceJob[]; skipped: number } {
  const [, ...rows] = values;
  const jobs: ServiceJob[] = [];
  let skipped = 0;
  rows.forEach((r, i) => {
    const date = isoOf(r[0]);
    const category = text(r[2]);
    const odometer = num(r[1]);
    if (!date && !category && odometer === null) return; // blank row
    if (!date || !category || odometer === null) {
      skipped++;
      return;
    }
    jobs.push({
      id: text(r[9]) || `row-${i + 2}`,
      row: i + 2,
      date,
      odometer,
      category,
      description: text(r[3]),
      costQar: num(r[4]),
      workshop: text(r[5]),
      nextDueKm: num(r[6]),
      nextDueDate: isoOf(r[7]),
      notes: text(r[8]),
    });
  });
  return { jobs, skipped };
}

/** The Service plan tab's values (header row first). Rows without a category are skipped. */
export function parsePlan(values: Cell[][]): PlanItem[] {
  const [, ...rows] = values;
  return rows.flatMap((r) => {
    const category = text(r[0]);
    if (!category) return [];
    return [{ category, everyKm: num(r[1]), everyMonths: num(r[2]) }];
  });
}

/** Adds whole months to a YYYY-MM-DD date, keeping the day where the month has one (31 Jan + 1 = 28/29 Feb). */
export function addMonths(iso: string, months: number): string {
  const [y, m, d] = iso.split("-").map(Number) as [number, number, number];
  const target = m - 1 + months;
  const year = y + Math.floor(target / 12);
  const month = ((target % 12) + 12) % 12;
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return new Date(Date.UTC(year, month, Math.min(d, lastDay))).toISOString().slice(0, 10);
}

/** Whole days from one YYYY-MM-DD date to another (negative when the second is earlier). */
export const daysBetween = (from: string, to: string) => Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);

const latestFirst = (a: ServiceJob, b: ServiceJob) => b.date.localeCompare(a.date) || b.odometer - a.odometer || b.row - a.row;

/**
 * What's due next, one line per category that has a starting job. For each category the countdown starts
 * from its latest job. A job's own next-due values win over the plan's intervals.
 */
export function dueItems(jobs: ServiceJob[], plan: PlanItem[], latestOdometer: number | null, today: string): DueItem[] {
  const items: DueItem[] = [];
  for (const p of plan) {
    const last = jobs.filter((j) => j.category === p.category).sort(latestFirst)[0];
    if (!last) continue;
    const dueKm = last.nextDueKm ?? (p.everyKm !== null ? last.odometer + p.everyKm : null);
    const dueDate = last.nextDueDate ?? (p.everyMonths !== null ? addMonths(last.date, p.everyMonths) : null);
    const kmLeft = dueKm !== null && latestOdometer !== null ? dueKm - latestOdometer : null;
    const daysLeft = dueDate !== null ? daysBetween(today, dueDate) : null;
    if (dueKm === null && dueDate === null) continue;
    const status: DueStatus =
      (kmLeft !== null && kmLeft <= 0) || (daysLeft !== null && daysLeft < 0)
        ? "overdue"
        : (kmLeft !== null && kmLeft <= DUE_SOON_KM) || (daysLeft !== null && daysLeft <= DUE_SOON_DAYS)
          ? "soon"
          : "ok";
    items.push({ category: p.category, status, last, dueKm, kmLeft, dueDate, daysLeft });
  }
  const rank: Record<DueStatus, number> = { overdue: 0, soon: 1, ok: 2 };
  return items.sort((a, b) => rank[a.status] - rank[b.status] || (a.kmLeft ?? Infinity) - (b.kmLeft ?? Infinity) || (a.daysLeft ?? Infinity) - (b.daysLeft ?? Infinity));
}

export interface JobInput {
  date: string;
  odometer: number;
  category: string;
  description: string;
  costQar: number | null;
  workshop: string;
  nextDueKm: number | null;
  nextDueDate: string | null;
  notes: string;
}

export type JobFieldErrors = Partial<Record<keyof JobInput, string>>;

export interface JobContext {
  today: string;
  /** Highest odometer reading in the sheet (fill-ups or jobs), or null if there are none. */
  highestOdometer: number | null;
  categories: string[];
}

/** Checks a job before it's written. Returns a message per field that's wrong. */
export function validateJob(input: Partial<JobInput>, ctx: JobContext): JobFieldErrors {
  const e: JobFieldErrors = {};
  if (!input.date || !ISO.test(input.date) || Number.isNaN(Date.parse(`${input.date}T00:00:00Z`))) e.date = "Pick a date.";
  else if (input.date > ctx.today) e.date = "The date can't be in the future.";

  const odo = input.odometer ?? Number.NaN;
  if (!Number.isFinite(odo) || odo < 0) e.odometer = "Enter the odometer reading.";
  else if (ctx.highestOdometer !== null && odo > ctx.highestOdometer + MAX_ODOMETER_JUMP_KM)
    e.odometer = `More than 2,000 km above the last reading (${ctx.highestOdometer.toLocaleString("en-GB")} km). Check it.`;

  if (!input.category || !ctx.categories.includes(input.category)) e.category = "Pick a category.";

  if (input.costQar !== null && input.costQar !== undefined && (!Number.isFinite(input.costQar) || input.costQar < 0 || input.costQar > 100000))
    e.costQar = "Enter an amount between 0 and 100,000 QAR, or leave it blank.";

  if (input.nextDueKm !== null && input.nextDueKm !== undefined) {
    if (!Number.isFinite(input.nextDueKm) || input.nextDueKm <= odo)
      e.nextDueKm = "The next due reading must be above this job's odometer.";
  }
  if (input.nextDueDate) {
    if (!ISO.test(input.nextDueDate)) e.nextDueDate = "Pick a valid date.";
    else if (input.date && input.nextDueDate <= input.date) e.nextDueDate = "The next due date must be after this job.";
  }

  if (input.description && input.description.length > 200) e.description = "Keep the description under 200 characters.";
  if (input.workshop && input.workshop.length > 60) e.workshop = "Keep the workshop name under 60 characters.";
  if (input.notes && input.notes.length > 500) e.notes = "Keep the notes under 500 characters.";
  return e;
}

export interface JobTotals {
  jobs: number;
  spendQar: number;
  /** Spend per 1,000 km between the first and last job's odometer; null when there isn't enough distance. */
  perThousandKm: number | null;
  byCategory: { category: string; spendQar: number; jobs: number }[];
}

/** Totals for a list of jobs (the caller filters by date range). */
export function jobTotals(jobs: ServiceJob[]): JobTotals {
  const spendQar = jobs.reduce((s, j) => s + (j.costQar ?? 0), 0);
  const odos = jobs.map((j) => j.odometer);
  const span = odos.length ? Math.max(...odos) - Math.min(...odos) : 0;
  const byMap = new Map<string, { spendQar: number; jobs: number }>();
  for (const j of jobs) {
    const cur = byMap.get(j.category) ?? { spendQar: 0, jobs: 0 };
    cur.spendQar += j.costQar ?? 0;
    cur.jobs += 1;
    byMap.set(j.category, cur);
  }
  return {
    jobs: jobs.length,
    spendQar,
    perThousandKm: span >= 1000 ? (spendQar / span) * 1000 : null,
    byCategory: [...byMap.entries()].map(([category, v]) => ({ category, ...v })).sort((a, b) => b.spendQar - a.spendQar),
  };
}
