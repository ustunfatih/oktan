import { describe, expect, it } from "vitest";
import {
  addMonths,
  daysBetween,
  DEFAULT_PLAN,
  dueItems,
  jobTotals,
  parseJobs,
  parsePlan,
  validateJob,
  type JobInput,
  type ServiceJob,
} from "./maintenance";
import { isoToSerial } from "./writes";

const job = (over: Partial<ServiceJob>): ServiceJob => ({
  id: "j1",
  row: 2,
  date: "2026-01-01",
  odometer: 10000,
  category: "Oil and filter",
  description: "",
  costQar: 150,
  workshop: "",
  nextDueKm: null,
  nextDueDate: null,
  notes: "",
  ...over,
});

const plan = [
  { category: "Oil and filter", everyKm: 10000, everyMonths: 12 },
  { category: "Battery", everyKm: null, everyMonths: 36 },
  { category: "Tyres", everyKm: 40000, everyMonths: null },
];

describe("addMonths", () => {
  it("adds whole months across a year boundary", () => {
    expect(addMonths("2026-11-15", 3)).toBe("2027-02-15");
    expect(addMonths("2026-01-31", 1)).toBe("2026-02-28");
  });
  it("keeps the day in a leap year", () => {
    expect(addMonths("2028-01-31", 1)).toBe("2028-02-29");
  });
  it("goes backwards too", () => {
    expect(addMonths("2026-03-10", -4)).toBe("2025-11-10");
  });
});

describe("daysBetween", () => {
  it("is negative when the second date is earlier", () => {
    expect(daysBetween("2026-10-27", "2026-10-20")).toBe(-7);
    expect(daysBetween("2026-10-27", "2026-11-03")).toBe(7);
  });
});

describe("parseJobs", () => {
  const header = ["Date", "Odometer km", "Category", "Description", "Cost QAR", "Workshop", "Next due km", "Next due date", "Notes", "ID"];
  it("reads serial dates, numbers and the hidden ID", () => {
    const { jobs, skipped } = parseJobs([
      header,
      [isoToSerial("2026-10-01"), 46000, "Tyres", "Two new tyres", 1200, "Al Meera", 86000, "", "Front pair first", "t1"],
    ]);
    expect(skipped).toBe(0);
    expect(jobs[0]).toMatchObject({ id: "t1", row: 2, date: "2026-10-01", odometer: 46000, costQar: 1200, nextDueKm: 86000, nextDueDate: null });
  });
  it("accepts a date typed as text", () => {
    const { jobs } = parseJobs([header, ["2026-09-30", 40000, "Oil and filter", "", "", "", "", "2027-09-30", "", "o1"]]);
    expect(jobs[0]).toMatchObject({ date: "2026-09-30", nextDueDate: "2027-09-30" });
  });
  it("skips blank rows silently and counts broken ones", () => {
    const { jobs, skipped } = parseJobs([
      header,
      [],
      [isoToSerial("2026-10-01"), null, "Tyres"],
      [isoToSerial("2026-10-02"), 41000, "Brakes", "", "", "", "", "", "", "b1"],
    ]);
    expect(jobs.map((j) => j.id)).toEqual(["b1"]);
    expect(skipped).toBe(1);
  });
  it("gives a row without an ID a stable stand-in", () => {
    const { jobs } = parseJobs([header, [isoToSerial("2026-10-01"), 41000, "Brakes"]]);
    expect(jobs[0]!.id).toBe("row-2");
  });
});

describe("parsePlan", () => {
  it("keeps categories with intervals and drops blank rows", () => {
    expect(parsePlan([["Category", "Every km", "Every months"], ["Oil and filter", 10000, 12], ["", 5, 5], ["Other", "", ""]])).toEqual([
      { category: "Oil and filter", everyKm: 10000, everyMonths: 12 },
      { category: "Other", everyKm: null, everyMonths: null },
    ]);
  });
});

describe("dueItems", () => {
  const today = "2026-10-27";

  it("counts km from the latest job in a category and months from its date", () => {
    const items = dueItems([job({ odometer: 40000, date: "2026-06-01" }), job({ id: "j2", odometer: 45000, date: "2026-10-01" })], plan, 46000, today);
    const oil = items.find((i) => i.category === "Oil and filter")!;
    expect(oil.last.odometer).toBe(45000);
    expect(oil.dueKm).toBe(55000);
    expect(oil.kmLeft).toBe(9000);
    expect(oil.dueDate).toBe("2027-10-01");
    expect(oil.daysLeft).toBe(339);
    expect(oil.status).toBe("ok");
  });

  it("uses a job's own next-due values over the plan", () => {
    const items = dueItems([job({ odometer: 45000, nextDueKm: 47000, nextDueDate: "2026-11-15" })], plan, 46500, today);
    expect(items[0]).toMatchObject({ dueKm: 47000, kmLeft: 500, dueDate: "2026-11-15", daysLeft: 19, status: "soon" });
  });

  it("is overdue at zero km left, or when the date has passed", () => {
    const byKm = dueItems([job({ odometer: 40000 })], plan, 50000, today)[0]!;
    expect(byKm).toMatchObject({ kmLeft: 0, status: "overdue" });
    const byDate = dueItems([job({ date: "2024-01-01", odometer: 1000 })], plan, 1200, today)[0]!;
    expect(byDate.daysLeft).toBeLessThan(0);
    expect(byDate.status).toBe("overdue");
  });

  it("is due soon at 1,000 km or 30 days, and not before", () => {
    expect(dueItems([job({ odometer: 40000 })], plan, 49000, today)[0]!.status).toBe("soon");
    expect(dueItems([job({ odometer: 40000 })], plan, 48999, today)[0]!.status).toBe("ok");
    const monthsOnly = [{ category: "Oil and filter", everyKm: null, everyMonths: 12 }];
    expect(dueItems([job({ date: "2025-10-30", odometer: 1000 })], monthsOnly, null, today)[0]!.status).toBe("soon");
  });

  it("skips categories with no record, and lists overdue first", () => {
    const items = dueItems([job({ odometer: 40000 })], plan, 52500, today);
    expect(items.map((i) => i.category)).toEqual(["Oil and filter"]);
    const mixed = dueItems(
      [job({ category: "Oil and filter", odometer: 40000 }), job({ id: "b", category: "Battery", date: "2020-01-01", odometer: 1 })],
      plan,
      41000,
      today,
    );
    expect(mixed[0]!.category).toBe("Battery");
    expect(mixed[0]!.status).toBe("overdue");
  });

  it("has no due time for a plan item with no interval", () => {
    expect(dueItems([job({ category: "Tyres", odometer: 1000 })], [{ category: "Tyres", everyKm: null, everyMonths: null }], 1000, today)).toEqual([]);
  });

  it("works from the built-in plan", () => {
    const items = dueItems([job({ odometer: 40000 })], DEFAULT_PLAN, 40500, today);
    expect(items[0]).toMatchObject({ category: "Oil and filter", dueKm: 50000 });
  });
});

describe("validateJob", () => {
  const ok: JobInput = {
    date: "2026-10-20",
    odometer: 46000,
    category: "Tyres",
    description: "Two tyres",
    costQar: 1200,
    workshop: "Al Meera",
    nextDueKm: null,
    nextDueDate: null,
    notes: "",
  };
  const ctx = { today: "2026-10-27", highestOdometer: 45500, categories: ["Tyres", "Other"] };

  it("accepts a sensible job", () => {
    expect(validateJob(ok, ctx)).toEqual({});
  });
  it("refuses a future date", () => {
    expect(validateJob({ ...ok, date: "2026-10-28" }, ctx).date).toMatch(/future/);
  });
  it("refuses an odometer far above the last reading, but accepts an earlier one", () => {
    expect(validateJob({ ...ok, odometer: 48000 }, ctx).odometer).toMatch(/2,000 km/);
    expect(validateJob({ ...ok, odometer: 40000 }, ctx).odometer).toBeUndefined();
  });
  it("refuses an unknown category", () => {
    expect(validateJob({ ...ok, category: "Wipers" }, ctx).category).toBeDefined();
  });
  it("limits cost", () => {
    expect(validateJob({ ...ok, costQar: -1 }, ctx).costQar).toBeDefined();
    expect(validateJob({ ...ok, costQar: 100001 }, ctx).costQar).toBeDefined();
    expect(validateJob({ ...ok, costQar: null }, ctx).costQar).toBeUndefined();
  });
  it("checks next due values against this job", () => {
    expect(validateJob({ ...ok, nextDueKm: 46000 }, ctx).nextDueKm).toBeDefined();
    expect(validateJob({ ...ok, nextDueKm: 56000 }, ctx).nextDueKm).toBeUndefined();
    expect(validateJob({ ...ok, nextDueDate: "2026-10-20" }, ctx).nextDueDate).toBeDefined();
    expect(validateJob({ ...ok, nextDueDate: "2027-10-20" }, ctx).nextDueDate).toBeUndefined();
  });
  it("caps text lengths", () => {
    expect(validateJob({ ...ok, description: "x".repeat(201) }, ctx).description).toBeDefined();
    expect(validateJob({ ...ok, notes: "x".repeat(501) }, ctx).notes).toBeDefined();
  });
});

describe("jobTotals", () => {
  it("sums spend, groups by category and works out cost per 1,000 km", () => {
    const t = jobTotals([
      job({ odometer: 40000, costQar: 150 }),
      job({ id: "b", category: "Tyres", odometer: 44000, costQar: 1200 }),
      job({ id: "c", category: "Oil and filter", odometer: 50000, costQar: null }),
    ]);
    expect(t.jobs).toBe(3);
    expect(t.spendQar).toBe(1350);
    expect(t.perThousandKm).toBeCloseTo(135, 2);
    expect(t.byCategory[0]).toEqual({ category: "Tyres", spendQar: 1200, jobs: 1 });
  });
  it("gives no per-km figure over less than 1,000 km", () => {
    expect(jobTotals([job({ odometer: 40000 }), job({ id: "b", odometer: 40500 })]).perThousandKm).toBeNull();
  });
});
