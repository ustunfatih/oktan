import { describe, expect, it } from "vitest";
import { dataTab } from "./__fixtures__/data-tab";
import { buildDashboard, monthRange } from "./dashboard";
import { DEFAULT_SETTINGS, parseEntries, parsePrices, parseSettings } from "./parse";

const entries = parseEntries(dataTab);
const prices = parsePrices([
  ["Month", "Price", "Source"],
  [46266, 2.1, "Sheet"], // Sep 2026
  [46296, 2.1, "WOQOD"], // Oct 2026
  [46327, "", ""], // Nov 2026, not known yet
]);
const settings = { ...DEFAULT_SETTINGS, tankCapacityL: 47 };

describe("monthRange", () => {
  it("includes both ends and crosses years", () => {
    expect(monthRange("2025-11", "2026-02")).toEqual(["2025-11", "2025-12", "2026-01", "2026-02"]);
  });
});

describe("buildDashboard", () => {
  const d = buildDashboard(entries, prices, settings, "2026-10-24");

  it("totals this year and this month", () => {
    expect(d.year.spend).toBeCloseTo(1052.51, 2);
    expect(d.year.fills).toBe(12);
    expect(d.month).toEqual({ spend: 91.01, fills: 1 });
  });

  it("lists every month from the first fill-up to today, empty months included", () => {
    expect(d.monthly).toHaveLength(19);
    expect(d.monthly[0]).toMatchObject({ month: "2025-04", fills: 2 });
    expect(d.monthly.find((m) => m.month === "2025-06")).toMatchObject({ spend: 0, fills: 0 });
    expect(d.monthly.find((m) => m.month === "2026-07")?.spend).toBeCloseTo(183.04, 2);
  });

  it("estimates the next fill-up from the average interval", () => {
    expect(d.nextFill).toEqual({ date: "2026-11-15", everyDays: 25 });
  });

  it("finds best, worst and the recent average", () => {
    expect(d.trend).toHaveLength(22);
    expect(d.best).toMatchObject({ date: "2025-12-06", value: 8.23 });
    expect(d.worst).toMatchObject({ date: "2025-07-20", value: 10.25 });
    // Distance-weighted, like the lifetime figure (a plain mean of the five would be 9.49).
    expect(d.last5LitersPer100Km).toBeCloseTo(9.48, 2);
  });

  it("derives range and efficiency from the tank size", () => {
    expect(d.kmPerLiter).toBeCloseTo(10.77, 2);
    expect(d.fullTankRangeKm).toBeCloseTo(506, 0);
  });

  it("picks this and last month's price", () => {
    expect(d.currentPrice).toEqual({ month: "2026-10", price: 2.1, source: "WOQOD" });
    expect(d.previousPrice?.month).toBe("2026-09");
  });

  it("shows the five latest fill-ups, newest first", () => {
    expect(d.recent.map((e) => e.date)).toEqual(["2026-10-21", "2026-09-10", "2026-08-22", "2026-07-30", "2026-07-05"]);
  });
});

describe("parseSettings", () => {
  it("reads the Settings tab", () => {
    const s = parseSettings([
      ["Setting", "Value", "Notes", "", "Stations", "", "Drive modes"],
      ["Theme", "auto", "…", "", "Pearl", "", "Eco"],
      ["Fuel grade", "Super 95", "…", "", "Dafna", "", "Normal"],
      ["Tank capacity (L)", 47, "…", "", "Fox Hills", "", "Sport"],
      ["Default drive mode", "Eco", "…", "", "Onaiza"],
      ["Currency", "QAR"],
    ]);
    expect(s).toEqual({
      theme: "auto",
      fuelGrade: "Super 95",
      tankCapacityL: 47,
      defaultMode: "Eco",
      currency: "QAR",
      stations: ["Pearl", "Dafna", "Fox Hills", "Onaiza"],
      stationList: ["Pearl", "Dafna", "Fox Hills", "Onaiza"].map((name) => ({ name, archived: false })),
      modes: ["Eco", "Normal", "Sport"],
    });
  });

  it("falls back to defaults for an empty tab", () => {
    expect(parseSettings([])).toEqual(DEFAULT_SETTINGS);
  });
});
