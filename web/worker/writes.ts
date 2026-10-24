import { COL_INDEX, PlanError, type CellValue, type Plan } from "../shared/writes";
import type { Entry } from "../shared/types";
import type { Env } from "./env";
import { batchUpdate, getMeta, type SheetMeta } from "./sheets";

const LOG_TAB = "App_Log";
const LOG_SHEET_ID = 6000;
/** Input columns that move together when a fill-up is deleted (B and J–O are formulas). */
const INPUT_SPANS: [number, number][] = [
  [0, 1], // A
  [2, 9], // C–I
  [15, 16], // P
];

export const cell = (value: CellValue) => {
  if (value === null) return {};
  if (typeof value === "number") return { userEnteredValue: { numberValue: value } };
  if (typeof value === "boolean") return { userEnteredValue: { boolValue: value } };
  return { userEnteredValue: { stringValue: value } };
};

export interface LogRecord {
  action: "add" | "edit" | "delete" | "price";
  email: string;
  entryId: string;
  before: Partial<Entry> | null;
  after: unknown;
}

/**
 * Applies a plan as one atomic batchUpdate: either every cell changes or none do.
 * Also grows the GasData table when a new row lands below it, and appends an App_Log row.
 */
export async function applyPlan(env: Env, spreadsheetId: string, plan: Plan, entries: Entry[], log: LogRecord) {
  // Re-check, against the rows just read, that every row the client based the change on is unchanged.
  for (const { row, id } of plan.expect) {
    if (!entries.some((e) => e.row === row && e.id === id)) {
      throw new PlanError("The sheet changed since this page loaded. Refreshed; please check and try again.");
    }
  }

  const meta = await getMeta(env, spreadsheetId);
  const data = meta.tabs.find((t) => t.title === "Data");
  if (!data) throw new PlanError("The sheet has no Data tab.");
  const requests: unknown[] = [];

  const table = meta.tables.find((t) => t.sheetId === data.sheetId);
  if (table && plan.row !== null && plan.row > table.endRowIndex) {
    requests.push({
      updateTable: { table: { tableId: table.tableId, range: { sheetId: data.sheetId, startRowIndex: 0, endRowIndex: plan.row, startColumnIndex: 0, endColumnIndex: 15 } }, fields: "range" },
    });
  }

  const grid = (row: number, c0: number, c1: number, rows = 1) => ({
    sheetId: data.sheetId,
    startRowIndex: row - 1,
    endRowIndex: row - 1 + rows,
    startColumnIndex: c0,
    endColumnIndex: c1,
  });

  for (const op of plan.ops) {
    if (op.kind === "set") {
      requests.push({ updateCells: { range: grid(op.row, COL_INDEX[op.col], COL_INDEX[op.col] + 1), rows: [{ values: [cell(op.value)] }], fields: "userEnteredValue" } });
    } else if (op.kind === "clearRow") {
      for (const [c0, c1] of INPUT_SPANS) requests.push({ updateCells: { range: grid(op.row, c0, c1), fields: "userEnteredValue" } });
    } else if (op.fromRow <= op.toRow) {
      // copyPaste keeps formulas (e.g. F = D×E) and re-points them at their new row.
      const rows = op.toRow - op.fromRow + 1;
      for (const [c0, c1] of INPUT_SPANS) {
        requests.push({ copyPaste: { source: grid(op.fromRow, c0, c1, rows), destination: grid(op.fromRow - 1, c0, c1, rows), pasteType: "PASTE_NORMAL" } });
      }
    }
  }

  requests.push(...appLogRequests(meta, [log.action, log.email, log.entryId, JSON.stringify(log.before), JSON.stringify(log.after)]));

  await batchUpdate(env, spreadsheetId, requests);
}

/** Requests that append one row to the hidden App_Log tab, creating the tab first if needed. */
export function appLogRequests(meta: SheetMeta, values: CellValue[]): unknown[] {
  const requests: unknown[] = [];
  if (!meta.tabs.some((t) => t.title === LOG_TAB)) {
    requests.push(
      { addSheet: { properties: { sheetId: LOG_SHEET_ID, title: LOG_TAB, hidden: true, gridProperties: { rowCount: 1000, columnCount: 6, frozenRowCount: 1 } } } },
      { appendCells: { sheetId: LOG_SHEET_ID, fields: "userEnteredValue", rows: [{ values: ["Time (UTC)", "Action", "By", "Entry ID", "Before", "After"].map(cell) }] } },
    );
  }
  const sheetId = meta.tabs.find((t) => t.title === LOG_TAB)?.sheetId ?? LOG_SHEET_ID;
  requests.push({
    appendCells: { sheetId, fields: "userEnteredValue", rows: [{ values: [new Date().toISOString(), ...values].map(cell) }] },
  });
  return requests;
}
