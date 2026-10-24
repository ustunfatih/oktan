import { describe, expect, it } from "vitest";
import { dataTab } from "./__fixtures__/data-tab";
import { checkHeaders, parseEntries, serialToIsoDate, SheetLayoutError } from "./parse";
import { lastClosedEntry, latestEntry, summarize } from "./metrics";

describe("serialToIsoDate", () => {
  it("converts Sheets date serials", () => {
    expect(serialToIsoDate(45763)).toBe("2025-04-16");
    expect(serialToIsoDate(46316)).toBe("2026-10-21");
  });
});

describe("checkHeaders", () => {
  it("accepts the live header row, line breaks included", () => {
    expect(() => checkHeaders(dataTab[0]!)).not.toThrow();
  });

  it("names the column that moved", () => {
    const moved = [...dataTab[0]!];
    [moved[7], moved[8]] = [moved[8]!, moved[7]!];
    expect(() => checkHeaders(moved)).toThrow(SheetLayoutError);
    expect(() => checkHeaders(moved)).toThrow(/column H: expected "Drive Mode"/);
  });
});

describe("parseEntries", () => {
  const entries = parseEntries(dataTab);

  it("reads every fill-up with its sheet row and ID", () => {
    expect(entries).toHaveLength(23);
    expect(entries[0]).toMatchObject({ row: 2, id: "a5ab7ac0", date: "2025-04-16", station: null, full: true });
    expect(entries[22]).toMatchObject({ row: 24, id: "0b96f058", odometer: 8774, odometerEnd: null, distanceKm: null });
  });

  it("skips rows without a date", () => {
    expect(parseEntries([...dataTab, ["", "", "", ""]])).toHaveLength(23);
  });
});

describe("summarize", () => {
  const entries = parseEntries(dataTab);
  const s = summarize(entries);

  it("matches the sheet's lifetime figures", () => {
    expect(s.fillUps).toBe(23);
    expect(s.closedTrips).toBe(22);
    expect(s.distanceKm).toBe(8761);
    expect(s.totalLiters).toBeCloseTo(955.33, 2);
    expect(s.totalSpend).toBeCloseTo(1939.84, 2);
    expect(s.litersPer100Km).toBeCloseTo(9.29, 2);
    expect(s.costPerKm).toBeCloseTo(0.188, 3);
    expect(s.avgKmPerTank).toBeCloseTo(398.2, 1);
  });

  it("finds the open trip and the last closed one", () => {
    expect(latestEntry(entries)?.date).toBe("2026-10-21");
    expect(lastClosedEntry(entries)?.date).toBe("2026-09-10");
  });
});
