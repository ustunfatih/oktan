import { describe, expect, it } from "vitest";
import { dataTab } from "./__fixtures__/data-tab";
import { parseEntries } from "./parse";
import { planStations, resolveTheme, validateSettings, type StationEdit } from "./settings";

const entries = parseEntries(dataTab);
const current = ["Pearl", "Dafna", "Fox Hills", "Onaiza"].map((name) => ({ name, archived: false }));
const edits = (): StationEdit[] => current.map((s) => ({ ...s, original: s.name }));

describe("resolveTheme", () => {
  it("prefers the device, falls back to Cluster for auto or unfinished themes", () => {
    expect(resolveTheme("auto", null)).toBe("cluster");
    expect(resolveTheme("swiss", null)).toBe("cluster");
    expect(resolveTheme("swiss", "cluster")).toBe("cluster");
  });
});

describe("validateSettings", () => {
  it("accepts sensible values and rejects the rest", () => {
    expect(validateSettings({ tankCapacityL: 47, fuelGrade: "Premium 91", defaultMode: "Normal", theme: "auto" }, ["Eco", "Normal", "Sport"])).toEqual({});
    const e = validateSettings({ tankCapacityL: 5, fuelGrade: "Gas", defaultMode: "Turbo", theme: "neon" }, ["Eco", "Normal", "Sport"]);
    expect(Object.keys(e).sort()).toEqual(["defaultMode", "fuelGrade", "tankCapacityL", "theme"]);
  });
});

describe("planStations", () => {
  it("adds, reorders and archives", () => {
    const list = edits().reverse();
    list.push({ name: "  Al Wakra ", archived: false });
    list[0]!.archived = true;
    const plan = planStations(current, list, entries, false);
    expect(plan.list.map((s) => s.name)).toEqual(["Onaiza", "Fox Hills", "Dafna", "Pearl", "Al Wakra"]);
    expect(plan.list[0]!.archived).toBe(true);
    expect(plan.renames).toEqual([]);
  });

  it("blocks deleting a station that past fill-ups use", () => {
    expect(() => planStations(current, edits().filter((s) => s.name !== "Onaiza"), entries, false)).toThrow(/used by 1 fill-up; archive it/);
  });

  it("allows deleting an unused station", () => {
    const withUnused = [...current, { name: "Old", archived: false }];
    expect(planStations(withUnused, edits(), entries, false).list).toHaveLength(4);
  });

  it("renames in history only when asked", () => {
    const list = edits();
    list[3]!.name = "Onaiza (Al Gharrafa)";
    expect(() => planStations(current, list, entries, false)).toThrow(/also rename in past fill-ups/);
    expect(planStations(current, list, entries, true).renames).toEqual([{ from: "Onaiza", to: "Onaiza (Al Gharrafa)" }]);
  });

  it("rejects duplicates and blanks", () => {
    expect(() => planStations(current, [...edits(), { name: "pearl", archived: false }], entries, false)).toThrow(/twice/);
    expect(() => planStations(current, [...edits(), { name: " ", archived: false }], entries, false)).toThrow(/empty/);
  });
});
