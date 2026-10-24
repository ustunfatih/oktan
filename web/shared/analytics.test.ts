import { describe, expect, it } from "vitest";
import { dataTab } from "./__fixtures__/data-tab";
import {
  applyFilters,
  avgPricePaid,
  byMode,
  byStation,
  cumulativeSpend,
  distribution,
  efficiencyHeat,
  priceHistory,
  rangeStart,
  records,
  seasonEfficiency,
} from "./analytics";
import { parseEntries, parsePrices } from "./parse";

const entries = parseEntries(dataTab);
const TODAY = "2026-10-24";
const prices = parsePrices([
  ["Month", "Price", "Source"],
  [45748, 2.05, "Sheet"], // Apr 2025
  [46054, 1.85, "Sheet"], // Feb 2026
  [46296, 2.1, "WOQOD"], // Oct 2026
  [46327, "", ""], // Nov 2026: no price yet
]);

describe("filters", () => {
  it("computes range starts", () => {
    expect(rangeStart("3m", TODAY)).toBe("2026-07-24");
    expect(rangeStart("12m", TODAY)).toBe("2025-10-24");
    expect(rangeStart("ytd", TODAY)).toBe("2026-01-01");
    expect(rangeStart("all", TODAY)).toBeNull();
  });

  it("combines range, mode and station", () => {
    expect(applyFilters(entries, { range: "ytd", mode: null, station: null }, TODAY)).toHaveLength(12);
    expect(applyFilters(entries, { range: "all", mode: "Sport", station: null }, TODAY)).toHaveLength(4);
    expect(applyFilters(entries, { range: "all", mode: null, station: "Dafna" }, TODAY)).toHaveLength(7);
    expect(applyFilters(entries, { range: "all", mode: null, station: "" }, TODAY)).toHaveLength(1);
  });
});

describe("byMode", () => {
  it("matches the sheet's distance-weighted figures, best first", () => {
    const m = byMode(entries, ["Eco", "Normal", "Sport"]);
    expect(m.map((g) => g.key)).toEqual(["Normal", "Eco", "Sport"]);
    expect(m[0]).toMatchObject({ trips: 8, km: 3316 });
    expect(m[0]!.litersPer100Km).toBeCloseTo(9.04, 2);
    expect(m[0]!.costPerKm).toBeCloseTo(0.182, 3);
    expect(m[1]!.litersPer100Km).toBeCloseTo(9.35, 2);
    expect(m[2]!.litersPer100Km).toBeCloseTo(9.65, 2);
  });
});

describe("byStation", () => {
  it("orders by spend and groups unrecorded stations", () => {
    const s = byStation(entries);
    expect(s.map((g) => g.key)).toEqual(["Pearl", "Dafna", "Fox Hills", "Onaiza", ""]);
    expect(s[0]).toMatchObject({ fills: 13 });
    expect(s[0]!.spend).toBeCloseTo(1109.21, 2);
    expect(s[1]).toMatchObject({ fills: 7, trips: 6 });
    expect(s[1]!.litersPer100Km).toBeCloseTo(9.44, 2);
  });
});

describe("seasons, heat and distribution", () => {
  it("compares summer and winter", () => {
    expect(seasonEfficiency(entries, [6, 7, 8]).litersPer100Km).toBeCloseTo(9.54, 2);
    expect(seasonEfficiency(entries, [12, 1, 2, 3]).litersPer100Km).toBeCloseTo(9.03, 2);
  });

  it("builds a year × month grid", () => {
    const heat = efficiencyHeat(entries);
    expect(heat.map((r) => r.year)).toEqual(["2025", "2026"]);
    expect(heat[0]!.cells[11]).toMatchObject({ month: "2025-12", trips: 1 });
    expect(heat[0]!.cells[11]!.litersPer100Km).toBeCloseTo(8.23, 2);
    expect(heat[1]!.cells[9]).toMatchObject({ month: "2026-10", trips: 0, litersPer100Km: null });
  });

  it("bins tanks by 0.5 L/100 km", () => {
    expect(distribution(entries).map((b) => [b.from, b.count])).toEqual([
      [8, 1],
      [8.5, 4],
      [9, 10],
      [9.5, 6],
      [10, 1],
    ]);
  });
});

describe("spend, prices and records", () => {
  it("accumulates spend", () => {
    const c = cumulativeSpend(entries);
    expect(c).toHaveLength(23);
    expect(c.at(-1)!.total).toBeCloseTo(1939.84, 2);
  });

  it("limits price history to the range and skips unknown months", () => {
    expect(priceHistory(prices, null, TODAY).map((p) => p.month)).toEqual(["2025-04", "2026-02", "2026-10"]);
    expect(priceHistory(prices, "2026-01-01", TODAY).map((p) => p.month)).toEqual(["2026-02", "2026-10"]);
  });

  it("finds the records", () => {
    const r = records(entries, prices);
    expect(r.bestTank?.date).toBe("2025-12-06");
    expect(r.worstTank?.date).toBe("2025-07-20");
    expect(r.longestTank?.distanceKm).toBe(459);
    expect(r.biggestFill?.liters).toBe(44.5);
    expect(r.priciestMonth?.month).toBe("2026-07");
    expect(r.cheapestPrice).toEqual({ month: "2026-02", price: 1.85, source: "Sheet" });
  });

  it("averages the price paid", () => {
    expect(avgPricePaid(entries)).toBeCloseTo(2.031, 3);
  });
});
