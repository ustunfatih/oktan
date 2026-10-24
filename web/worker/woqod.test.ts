import { describe, expect, it } from "vitest";
import { parseWoqod } from "./woqod";

// Shape of the real response on 24 Oct 2026: a JSON string containing the JSON array.
const raw = JSON.stringify([
  { date: "2026-10-01T00:00:00", dateFrom: "2026-10-01T00:00:00", fuelTypeEn: "Diesel", price: "2.05" },
  { date: "2026-10-01T00:00:00", dateFrom: "2026-10-01T00:00:00", fuelTypeEn: "Gasoline Premium (91)", price: "1.95" },
  { date: "2026-10-01T00:00:00", dateFrom: "2026-10-01T00:00:00", fuelTypeEn: "Gasoline Super (95)", price: "2.10" },
]);

describe("parseWoqod", () => {
  it("parses the double-encoded body", () => {
    expect(parseWoqod(raw)).toEqual([
      { grade: "Diesel", price: 2.05, month: "2026-10" },
      { grade: "Gasoline Premium (91)", price: 1.95, month: "2026-10" },
      { grade: "Gasoline Super (95)", price: 2.1, month: "2026-10" },
    ]);
  });

  it("skips malformed rows", () => {
    expect(parseWoqod(JSON.stringify([{ fuelTypeEn: "Diesel", price: "n/a", dateFrom: "2026-10-01" }, {}]))).toEqual([]);
  });

  it("rejects an unexpected shape", () => {
    expect(() => parseWoqod({ prices: [] })).toThrow();
  });
});
