import { describe, expect, it } from "vitest";
import { niceStep, robustRange, ticks } from "./scale";

describe("niceStep", () => {
  it("picks steps of 1, 2, 2.5, 5 or 10 powers of ten", () => {
    expect(niceStep(10, 5)).toBe(2);
    expect(niceStep(3, 5)).toBe(1);
    expect(niceStep(1, 5)).toBe(0.2);
    expect(niceStep(250, 5)).toBe(50);
  });
  it("never gives more intervals than asked for", () => {
    for (const span of [0.7, 3, 9.9, 27, 180, 1234]) {
      expect(span / niceStep(span, 5)).toBeLessThanOrEqual(5 + 1e-9);
    }
  });
});

describe("ticks", () => {
  it("gives a handful of readable labels, never dozens", () => {
    expect(ticks(7, 11, 5)).toEqual([7, 8, 9, 10, 11]);
    expect(ticks(8, 29.5, 5).length).toBeLessThanOrEqual(6);
  });
});

describe("robustRange", () => {
  it("ignores one wild value so the axis stays readable", () => {
    const values = [8.9, 9.1, 9.4, 8.2, 9.8, 10.1, 9.0, 8.8, 9.6, 9.2, 28.84];
    const r = robustRange(values);
    expect(r.outliers.has(28.84)).toBe(true);
    expect(r.hi).toBeLessThanOrEqual(11);
    expect(r.lo).toBeGreaterThanOrEqual(7);
    expect(ticks(r.lo, r.hi, 5).length).toBeLessThanOrEqual(6);
  });
  it("keeps every real value on the axis when there are no outliers", () => {
    const r = robustRange([7.8, 9.2, 12.1, 10.4]);
    expect(r.outliers.size).toBe(0);
    expect(r.lo).toBeLessThanOrEqual(7.8);
    expect(r.hi).toBeGreaterThanOrEqual(12.1);
  });
  it("gives a usable range for a single value or flat data", () => {
    const r = robustRange([9.3]);
    expect(r.hi - r.lo).toBeGreaterThanOrEqual(1);
    expect(r.lo).toBeLessThanOrEqual(9.3);
    expect(r.hi).toBeGreaterThanOrEqual(9.3);
  });
});
