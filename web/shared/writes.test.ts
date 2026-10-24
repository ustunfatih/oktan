import { describe, expect, it } from "vitest";
import { dataTab } from "./__fixtures__/data-tab";
import { parseEntries } from "./parse";
import { deleteConsequence, isoToSerial, planAdd, planDelete, planEdit, PlanError, validateEntry, type EntryInput } from "./writes";

const entries = parseEntries(dataTab);
const last = entries.at(-1)!; // 21 Oct 2026, row 24, open trip from 8,774 km
const input: EntryInput = {
  date: "2026-10-24",
  odometer: 9183,
  liters: 41.8,
  pricePerLiter: 2.1,
  totalCost: 87.78,
  full: true,
  mode: "Eco",
  station: "Dafna",
};
const ctx = { prev: last, next: null, today: "2026-10-24", tankCapacityL: 47 };

describe("isoToSerial", () => {
  it("matches the sheet's date serials", () => {
    expect(isoToSerial("2025-04-16")).toBe(45763);
    expect(isoToSerial("2026-10-21")).toBe(46316);
  });
});

describe("validateEntry", () => {
  it("accepts a sensible fill-up", () => {
    expect(validateEntry(input, ctx)).toEqual({});
  });

  it("rejects readings that go backwards or dates in the wrong order", () => {
    const e = validateEntry({ ...input, odometer: 8700, date: "2026-10-01" }, ctx);
    expect(e.odometer).toMatch(/more than the previous reading \(8,774 km\)/);
    expect(e.date).toMatch(/on or after the previous fill-up/);
  });

  it("rejects the future, impossible litres and mismatched totals", () => {
    const e = validateEntry({ ...input, date: "2026-10-25", liters: 60, totalCost: 50 }, ctx);
    expect(e.date).toMatch(/future/);
    expect(e.liters).toMatch(/47 L tank/);
    expect(e.totalCost).toMatch(/Doesn't match/);
  });

  it("checks an edit against the next fill-up too", () => {
    const prev = entries[20]!;
    const next = entries[22]!;
    const e = validateEntry({ ...input, date: "2026-10-22", odometer: 8800 }, { ...ctx, prev, next });
    expect(e.date).toMatch(/on or before the next fill-up/);
    expect(e.odometer).toMatch(/less than the next reading \(8,774 km\)/);
  });
});

describe("planAdd", () => {
  it("closes the open trip and writes the next row", () => {
    const plan = planAdd(entries, input, "abcd1234", last.id);
    expect(plan.row).toBe(25);
    expect(plan.expect).toEqual([{ row: 24, id: last.id }]);
    expect(plan.ops[0]).toEqual({ kind: "set", row: 24, col: "C", value: 9183 });
    expect(plan.ops).toContainEqual({ kind: "set", row: 25, col: "A", value: isoToSerial("2026-10-24") });
    expect(plan.ops).toContainEqual({ kind: "set", row: 25, col: "P", value: "abcd1234" });
    expect(plan.ops).toContainEqual({ kind: "set", row: 25, col: "G", value: true });
  });

  it("refuses if someone added a row since the form loaded", () => {
    expect(() => planAdd(entries, input, "x", entries[21]!.id)).toThrow(PlanError);
  });

  it("starts in row 2 on an empty sheet", () => {
    const plan = planAdd([], input, "first", null);
    expect(plan.row).toBe(2);
    expect(plan.ops[0]).toEqual({ kind: "set", row: 2, col: "B", value: 9183 });
  });
});

describe("planEdit", () => {
  const target = entries[21]!; // 10 Sep 2026, row 23

  it("rewrites the row and moves the odometer into the previous row's C", () => {
    const plan = planEdit(entries, target.id, { ...input, date: "2026-09-10", odometer: 8360 }, 23);
    expect(plan.ops[0]).toEqual({ kind: "set", row: 22, col: "C", value: 8360 });
    expect(plan.ops).toContainEqual({ kind: "set", row: 23, col: "D", value: 41.8 });
  });

  it("leaves the odometer alone when it didn't change", () => {
    const plan = planEdit(entries, target.id, { ...input, date: "2026-09-10", odometer: 8355 }, 23);
    expect(plan.ops.some((o) => o.kind === "set" && o.col === "C")).toBe(false);
  });

  it("writes B2 when editing the first fill-up's odometer", () => {
    const plan = planEdit(entries, entries[0]!.id, { ...input, date: "2025-04-16", odometer: 15 }, 2);
    expect(plan.ops[0]).toEqual({ kind: "set", row: 2, col: "B", value: 15 });
  });

  it("refuses when the row moved", () => {
    expect(() => planEdit(entries, target.id, input, 22)).toThrow(PlanError);
  });
});

describe("planDelete", () => {
  it("deleting the latest reopens the previous trip", () => {
    const plan = planDelete(entries, last.id, 24);
    expect(plan.ops).toEqual([
      { kind: "set", row: 23, col: "C", value: null },
      { kind: "clearRow", row: 24 },
    ]);
  });

  it("deleting a middle fill-up merges the trips and moves the rows below up", () => {
    const mid = entries[10]!; // 6 Dec 2025, row 12, odometer 3,762 → 4,221
    const plan = planDelete(entries, mid.id, 12);
    expect(plan.ops).toEqual([
      { kind: "set", row: 11, col: "C", value: 4221 },
      { kind: "shiftUp", fromRow: 13, toRow: 24 },
      { kind: "clearRow", row: 24 },
    ]);
    expect(plan.expect).toContainEqual({ row: 11, id: entries[9]!.id });
  });

  it("deleting the first fill-up moves the second's odometer into B2", () => {
    const plan = planDelete(entries, entries[0]!.id, 2);
    expect(plan.ops[0]).toEqual({ kind: "set", row: 2, col: "B", value: 170 });
    expect(plan.ops[1]).toEqual({ kind: "shiftUp", fromRow: 3, toRow: 24 });
  });

  it("explains the consequence", () => {
    expect(deleteConsequence(entries, last.id)).toBe("The trip from 2026-09-10 becomes the open trip again.");
    expect(deleteConsequence(entries, entries[10]!.id)).toMatch(/^The trips from 2025-11-19 and 2025-12-06 merge into one trip\. .*use Edit instead\.$/);
  });
});

import { priceForDate, woqodForGrade } from "./prices";

describe("priceForDate", () => {
  const prices = [
    { month: "2026-09", price: 2.1, source: "Sheet" },
    { month: "2026-10", price: null, source: null },
  ];
  const woqod = woqodForGrade(
    [
      { grade: "Gasoline Premium (91)", price: 1.95, month: "2026-10" },
      { grade: "Gasoline Super (95)", price: 2.1, month: "2026-10" },
    ],
    "Super 95",
  );

  it("uses the sheet's price for that month first", () => {
    expect(priceForDate("2026-09-10", prices, woqod)).toEqual({ price: 2.1, source: "Fuel Prices tab", month: "2026-09" });
  });

  it("falls back to WOQOD for the current month, then the last known price", () => {
    expect(priceForDate("2026-10-24", prices, woqod)).toEqual({ price: 2.1, source: "WOQOD", month: "2026-10" });
    expect(priceForDate("2026-11-02", prices, woqod)?.source).toBe("last known (2026-09)");
  });
});
