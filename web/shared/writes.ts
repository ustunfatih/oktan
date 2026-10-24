import type { Entry } from "./types";

/** What the Log form sends for a new or edited fill-up. */
export interface EntryInput {
  date: string;
  /** Odometer reading at this fill-up. */
  odometer: number;
  liters: number;
  pricePerLiter: number;
  totalCost: number;
  full: boolean;
  mode: string;
  station: string;
}

export type FieldErrors = Partial<Record<keyof EntryInput | "form", string>>;

/**
 * Data tab columns the app writes. B (odometer PRE) is a formula from row 3 down; only B2 is typed.
 * J–O are formulas. P holds the entry ID.
 */
export type Col = "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "P";
export const COL_INDEX: Record<Col, number> = { A: 0, B: 1, C: 2, D: 3, E: 4, F: 5, G: 6, H: 7, I: 8, P: 15 };

export type CellValue = number | string | boolean | null;

/** One step of a sheet change; the Worker turns these into a single atomic batchUpdate. */
export type Op =
  | { kind: "set"; row: number; col: Col; value: CellValue }
  /** Move the input columns of rows from..to up by one row (formulas in E/F keep pointing at their own row). */
  | { kind: "shiftUp"; fromRow: number; toRow: number }
  /** Empty the input columns of one row. */
  | { kind: "clearRow"; row: number };

export interface Plan {
  ops: Op[];
  /** Row the entry ends up in (add/edit). */
  row: number | null;
  /** Rows whose ID must still be what the client saw, checked right before writing. */
  expect: { row: number; id: string }[];
}

export class PlanError extends Error {
  constructor(
    message: string,
    readonly fields: FieldErrors = { form: message },
  ) {
    super(message);
  }
}

const isIsoDate = (s: string) => /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(`${s}T00:00:00Z`));
const round2 = (n: number) => Math.round(n * 100) / 100;

/** YYYY-MM-DD to a Google Sheets date serial. */
export const isoToSerial = (iso: string) => Math.round(Date.parse(`${iso}T00:00:00Z`) / 86_400_000) + 25569;

/**
 * Checks one fill-up against the fill-ups before and after it.
 * Used by the form (as you type) and again by the Worker (before writing).
 */
export function validateEntry(
  input: Partial<EntryInput>,
  ctx: { prev: Entry | null; next: Entry | null; today: string; tankCapacityL: number },
): FieldErrors {
  const e: FieldErrors = {};
  const { prev, next } = ctx;

  if (!input.date || !isIsoDate(input.date)) e.date = "Pick a date.";
  else if (input.date > ctx.today) e.date = "The date can't be in the future.";
  else if (prev && input.date < prev.date) e.date = `Must be on or after the previous fill-up (${prev.date}).`;
  else if (next && input.date > next.date) e.date = `Must be on or before the next fill-up (${next.date}).`;

  const odo = input.odometer;
  if (odo === undefined || !Number.isFinite(odo) || odo < 0) e.odometer = "Enter the odometer reading.";
  else if (prev?.odometer != null && odo <= prev.odometer)
    e.odometer = `Must be more than the previous reading (${prev.odometer.toLocaleString("en-GB")} km).`;
  else if (next?.odometer != null && odo >= next.odometer)
    e.odometer = `Must be less than the next reading (${next.odometer.toLocaleString("en-GB")} km).`;
  else if (prev?.odometer != null && odo - prev.odometer > 2000) e.odometer = "That's over 2,000 km since the last fill-up. Check the reading.";

  const l = input.liters;
  if (l === undefined || !Number.isFinite(l) || l <= 0) e.liters = "Enter the litres.";
  else if (l > ctx.tankCapacityL + 5) e.liters = `More than the ${ctx.tankCapacityL} L tank holds. Check the amount.`;

  const p = input.pricePerLiter;
  if (p === undefined || !Number.isFinite(p) || p <= 0) e.pricePerLiter = "Enter the price per litre.";
  else if (p < 0.5 || p > 5) e.pricePerLiter = "Prices in Qatar are between QAR 0.50 and 5.00.";

  const c = input.totalCost;
  if (c === undefined || !Number.isFinite(c) || c <= 0) e.totalCost = "Enter the total cost.";
  else if (l && p && Math.abs(c - l * p) > Math.max(1, l * p * 0.03))
    e.totalCost = `Doesn't match ${round2(l)} L × ${round2(p)} = ${round2(l * p).toFixed(2)}.`;

  if (!input.mode) e.mode = "Pick a drive mode.";
  if (input.station !== undefined && input.station.length > 60) e.station = "Keep the station name under 60 characters.";
  return e;
}

const fields = (input: EntryInput, row: number): Op[] => [
  { kind: "set", row, col: "A", value: isoToSerial(input.date) },
  { kind: "set", row, col: "D", value: round2(input.liters) },
  { kind: "set", row, col: "E", value: round2(input.pricePerLiter) },
  { kind: "set", row, col: "F", value: round2(input.totalCost) },
  { kind: "set", row, col: "G", value: input.full },
  { kind: "set", row, col: "H", value: input.mode },
  { kind: "set", row, col: "I", value: input.station.trim() || null },
];

/** Odometer at a fill-up lives in B2 for the first row, otherwise in the previous row's C. */
const odometerOp = (entries: Entry[], index: number, value: CellValue): Op =>
  index === 0
    ? { kind: "set", row: entries[0]?.row ?? 2, col: "B", value }
    : { kind: "set", row: entries[index - 1]!.row, col: "C", value };

/** New fill-up after the last one: closes the open trip and writes the next free row. */
export function planAdd(entries: Entry[], input: EntryInput, id: string, lastIdSeen: string | null): Plan {
  const last = entries.at(-1) ?? null;
  if ((last?.id ?? null) !== lastIdSeen) throw new PlanError("The sheet changed since you opened the form. Refreshed; please check and save again.");
  const row = last ? last.row + 1 : 2;
  return {
    row,
    expect: last ? [{ row: last.row, id: last.id }] : [],
    ops: [
      last ? { kind: "set", row: last.row, col: "C", value: input.odometer } : { kind: "set", row: 2, col: "B", value: input.odometer },
      ...fields(input, row),
      { kind: "set", row, col: "P", value: id },
    ],
  };
}

export function planEdit(entries: Entry[], id: string, input: EntryInput, rowSeen: number): Plan {
  const index = entries.findIndex((e) => e.id === id);
  const entry = entries[index];
  if (!entry || entry.row !== rowSeen) throw new PlanError("That fill-up moved or was removed in the sheet. Refreshed; please try again.");
  const ops: Op[] = [...fields(input, entry.row)];
  if (input.odometer !== entry.odometer) ops.unshift(odometerOp(entries, index, input.odometer));
  const expect = [{ row: entry.row, id: entry.id }];
  if (index > 0) expect.push({ row: entries[index - 1]!.row, id: entries[index - 1]!.id });
  return { row: entry.row, expect, ops };
}

/**
 * Removes a fill-up without deleting sheet rows (rows 2–3 hold the column formulas):
 * the rows below move up one, and the trips either side are re-linked.
 */
export function planDelete(entries: Entry[], id: string, rowSeen: number): Plan {
  const index = entries.findIndex((e) => e.id === id);
  const entry = entries[index];
  if (!entry || entry.row !== rowSeen) throw new PlanError("That fill-up moved or was removed in the sheet. Refreshed; please try again.");
  const last = entries.at(-1)!;
  const prev = index > 0 ? entries[index - 1]! : null;
  const expect = [{ row: entry.row, id: entry.id }, { row: last.row, id: last.id }];
  const ops: Op[] = [];

  if (entries.length === 1) {
    ops.push({ kind: "set", row: entry.row, col: "B", value: null }, { kind: "clearRow", row: entry.row });
  } else if (index === entries.length - 1) {
    // Latest fill-up: the previous trip becomes the open one again.
    ops.push({ kind: "set", row: prev!.row, col: "C", value: null }, { kind: "clearRow", row: entry.row });
  } else {
    if (index === 0) {
      // The second fill-up becomes the first, so its odometer moves into B2.
      ops.push({ kind: "set", row: entry.row, col: "B", value: entries[1]!.odometer });
    } else {
      // The previous trip now runs to the fill-up after the deleted one.
      ops.push({ kind: "set", row: prev!.row, col: "C", value: entry.odometerEnd });
      expect.push({ row: prev!.row, id: prev!.id });
    }
    ops.push({ kind: "shiftUp", fromRow: entry.row + 1, toRow: last.row }, { kind: "clearRow", row: last.row });
  }
  return { row: null, expect, ops };
}

/** Plain-language consequence shown before a delete. `fmt` formats the YYYY-MM-DD dates for display. */
export function deleteConsequence(entries: Entry[], id: string, fmt: (iso: string) => string = (iso) => iso): string {
  const index = entries.findIndex((e) => e.id === id);
  if (index < 0) return "";
  if (entries.length === 1) return "This is your only fill-up.";
  if (index === entries.length - 1) return `The trip from ${fmt(entries[index - 1]!.date)} becomes the open trip again.`;
  if (index === 0) return `${fmt(entries[1]!.date)} becomes your first fill-up.`;
  return (
    `The trips from ${fmt(entries[index - 1]!.date)} and ${fmt(entries[index]!.date)} merge into one trip. ` +
    "The litres bought at this fill-up disappear with it, so that trip's L/100 km will read too low. To fix a typo, use Edit instead."
  );
}
