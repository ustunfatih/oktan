import { PlanError, isoToSerial, type CellValue, type FieldErrors } from "../shared/writes";
import {
  DEFAULT_PLAN,
  dueItems,
  JOBS_HEADERS,
  JOBS_TAB,
  parseJobs,
  parsePlan,
  PLAN_HEADERS,
  PLAN_TAB,
  type JobInput,
  type PlanItem,
  type ServiceJob,
} from "../shared/maintenance";
import type { ServiceState } from "../shared/types";
import type { Cell } from "./sheets";
import type { Env } from "./env";
import { batchUpdate, forgetTabs, tabsOf } from "./sheets";
import { appLogRequests, cell } from "./writes";

/** Sheet ids for the two tabs this module creates. Chosen high so they can't clash with the sheet's own tabs. */
export const JOBS_SHEET_ID = 7000;
export const PLAN_SHEET_ID = 7001;

export interface ServiceSheet {
  /** Whether the Maintenance and Service plan tabs exist yet. */
  hasJobsTab: boolean;
  hasPlanTab: boolean;
  /** Raw rows in the Maintenance tab, header included. Used to detect a change before a save. */
  rowCount: number;
}

type Request = Record<string, unknown>;

/** The Sheets requests for a job row: columns A–J, with the hidden ID in J. */
export function jobRowCells(input: JobInput, id: string): CellValue[] {
  return [
    isoToSerial(input.date),
    input.odometer,
    input.category,
    input.description || null,
    input.costQar,
    input.workshop || null,
    input.nextDueKm,
    input.nextDueDate ? isoToSerial(input.nextDueDate) : null,
    input.notes || null,
    id,
  ];
}

const rowRequest = (sheetId: number, row: number, values: CellValue[]): Request => ({
  updateCells: {
    range: { sheetId, startRowIndex: row - 1, endRowIndex: row, startColumnIndex: 0, endColumnIndex: values.length },
    rows: [{ values: values.map(cell) }],
    fields: "userEnteredValue",
  },
});

const headerRequest = (sheetId: number, headers: readonly string[]): Request => ({
  updateCells: {
    range: { sheetId, startRowIndex: 0, endRowIndex: 1, startColumnIndex: 0, endColumnIndex: headers.length },
    rows: [{ values: headers.map((h) => cell(h)) }],
    fields: "userEnteredValue",
  },
});

const addTab = (sheetId: number, title: string, frozenRowCount: number, columnCount: number): Request => ({
  addSheet: { properties: { sheetId, title, gridProperties: { rowCount: 1000, columnCount, frozenRowCount } } },
});

/**
 * Adds a job. The row goes after the last raw row the client saw; if someone has added rows since, the
 * client's count no longer matches and the save is refused.
 */
export function planAddJob(sheet: ServiceSheet, input: JobInput, id: string, rowCountSeen: number): { requests: Request[]; row: number; tabsCreated: boolean } {
  if (sheet.rowCount !== rowCountSeen) throw new PlanError("Your service list changed since this page loaded. Refreshed; please check and save again.");
  const requests: Request[] = [];
  const row = Math.max(2, sheet.rowCount + 1);
  if (!sheet.hasJobsTab) {
    requests.push(addTab(JOBS_SHEET_ID, JOBS_TAB, 1, JOBS_HEADERS.length), headerRequest(JOBS_SHEET_ID, JOBS_HEADERS));
  }
  requests.push(rowRequest(JOBS_SHEET_ID, row, jobRowCells(input, id)));
  return { requests, row, tabsCreated: !sheet.hasJobsTab };
}

/** Changes a job in place. The row must still hold the job the client is editing. */
export function planEditJob(jobs: ServiceJob[], id: string, input: JobInput, rowSeen: number): { requests: Request[]; row: number } {
  const job = jobs.find((j) => j.id === id);
  if (!job) throw new PlanError("That job is no longer in the sheet.");
  if (job.row !== rowSeen) throw new PlanError("The sheet changed since this page loaded. Refreshed; please check and try again.");
  return { requests: [rowRequest(JOBS_SHEET_ID, job.row, jobRowCells(input, id))], row: job.row };
}

/** Deletes a job's row. The Maintenance tab has no formulas, so rows below simply move up. */
export function planDeleteJob(jobs: ServiceJob[], id: string, rowSeen: number): { requests: Request[]; row: number; job: ServiceJob } {
  const job = jobs.find((j) => j.id === id);
  if (!job) throw new PlanError("That job is no longer in the sheet.");
  if (job.row !== rowSeen) throw new PlanError("The sheet changed since this page loaded. Refreshed; please check and try again.");
  return {
    requests: [{ deleteDimension: { range: { sheetId: JOBS_SHEET_ID, dimension: "ROWS", startIndex: job.row - 1, endIndex: job.row } } }],
    row: job.row,
    job,
  };
}

/** Rewrites the whole Service plan tab (header and every category). Rows left over from a longer plan are cleared. */
export function planSavePlan(sheet: ServiceSheet, plan: PlanItem[], oldCount: number): { requests: Request[]; tabsCreated: boolean } {
  const requests: Request[] = [];
  if (!sheet.hasPlanTab) requests.push(addTab(PLAN_SHEET_ID, PLAN_TAB, 1, PLAN_HEADERS.length), headerRequest(PLAN_SHEET_ID, PLAN_HEADERS));
  const rows = Math.max(plan.length, oldCount, 1);
  const values: CellValue[][] = Array.from({ length: rows }, (_, i) => {
    const p = plan[i];
    return p ? [p.category, p.everyKm, p.everyMonths] : [null, null, null];
  });
  requests.push({
    updateCells: {
      range: { sheetId: PLAN_SHEET_ID, startRowIndex: 1, endRowIndex: 1 + rows, startColumnIndex: 0, endColumnIndex: PLAN_HEADERS.length },
      rows: values.map((r) => ({ values: r.map(cell) })),
      fields: "userEnteredValue",
    },
  });
  return { requests, tabsCreated: !sheet.hasPlanTab };
}

/** Checks a plan before it's saved: names, uniqueness, and sensible intervals. */
export function validatePlan(plan: PlanItem[]): FieldErrors | null {
  if (plan.length > 30) return { form: "Keep the plan to 30 categories or fewer." };
  const seen = new Set<string>();
  for (const p of plan) {
    const name = p.category.trim();
    if (!name) return { form: "Every category needs a name." };
    if (name.length > 40) return { form: "Keep category names under 40 characters." };
    const key = name.toLowerCase();
    if (seen.has(key)) return { form: `"${name}" is listed twice.` };
    seen.add(key);
    if (p.everyKm !== null && (!Number.isInteger(p.everyKm) || p.everyKm < 1000 || p.everyKm > 500000)) return { form: `${name}: every km must be a whole number from 1,000 to 500,000, or blank.` };
    if (p.everyMonths !== null && (!Number.isInteger(p.everyMonths) || p.everyMonths < 1 || p.everyMonths > 120)) return { form: `${name}: every months must be from 1 to 120, or blank.` };
  }
  return null;
}

/** Applies a service change as one batch and writes an App_Log row for it. Forgets the cached tab list when tabs were created. */
export async function applyService(env: Env, spreadsheetId: string, requests: Request[], log: { action: string; email: string; entryId: string; before: unknown; after: unknown }, created: boolean) {
  const meta = await tabsOf(env, spreadsheetId, true);
  const all = [...requests, ...appLogRequests(meta, [log.action, log.email, log.entryId, JSON.stringify(log.before), JSON.stringify(log.after)])];
  await batchUpdate(env, spreadsheetId, all);
  if (created) await forgetTabs(spreadsheetId);
}

/** What the app shows for service: the parsed jobs and plan, plus what's due. Missing tabs give the defaults. */
export function serviceState(wb: { jobs: Cell[][]; plan: Cell[][]; hasJobsTab: boolean; hasPlanTab: boolean }, odometers: (number | null)[], today: string): ServiceState {
  const { jobs, skipped } = parseJobs(wb.jobs);
  const plan = wb.hasPlanTab ? parsePlan(wb.plan) : DEFAULT_PLAN;
  const readings = [...odometers, ...jobs.map((j) => j.odometer)].filter((n): n is number => typeof n === "number");
  const highestOdometer = readings.length ? Math.max(...readings) : null;
  return {
    jobs,
    rowCount: wb.jobs.length,
    skipped,
    plan,
    planIsDefault: !wb.hasPlanTab,
    hasJobsTab: wb.hasJobsTab,
    highestOdometer,
    due: dueItems(jobs, plan, highestOdometer, today),
  };
}
