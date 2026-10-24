import { describe, expect, it } from "vitest";
import { decidePriceWrite, parsePriceRows } from "./prices";

const rows = parsePriceRows([
  ["Month", "Price", "Source"],
  [46266, 2.1, "Sheet"], // Sep 2026, row 3
  [46296, 2.1, "WOQOD"], // Oct 2026, row 4
  [46327, "", ""], // Nov 2026, row 5
  [46357, 2.2, "Manual"], // Dec 2026, row 6
]);

describe("parsePriceRows", () => {
  it("keeps sheet row numbers", () => {
    expect(rows.map((r) => [r.row, r.month, r.price, r.source])).toEqual([
      [3, "2026-09", 2.1, "Sheet"],
      [4, "2026-10", 2.1, "WOQOD"],
      [5, "2026-11", null, null],
      [6, "2026-12", 2.2, "Manual"],
    ]);
  });
});

describe("decidePriceWrite", () => {
  it("fills an empty month", () => {
    expect(decidePriceWrite(rows, "2026-11", 2.15, "WOQOD")).toMatchObject({ action: "write", row: 5, append: false });
  });

  it("skips a value that is already saved", () => {
    expect(decidePriceWrite(rows, "2026-10", 2.1, "WOQOD")).toMatchObject({ action: "skip" });
  });

  it("lets WOQOD confirm a price typed earlier, and replace it if different", () => {
    expect(decidePriceWrite(rows, "2026-09", 2.1, "WOQOD")).toMatchObject({ action: "write", row: 3 });
    expect(decidePriceWrite(rows, "2026-09", 2.05, "WOQOD")).toMatchObject({ action: "write", row: 3 });
  });

  it("never lets WOQOD overwrite a manual price", () => {
    const d = decidePriceWrite(rows, "2026-12", 2.1, "WOQOD");
    expect(d).toMatchObject({ action: "skip" });
    expect(d.action === "skip" && d.reason).toMatch(/manual price/);
  });

  it("lets a manual price overwrite anything", () => {
    expect(decidePriceWrite(rows, "2026-10", 2.2, "Manual")).toMatchObject({ action: "write", row: 4 });
    expect(decidePriceWrite(rows, "2026-12", 2.25, "Manual")).toMatchObject({ action: "write", row: 6 });
  });

  it("appends a month after the end of the list", () => {
    expect(decidePriceWrite(rows, "2027-01", 2.1, "WOQOD")).toMatchObject({ action: "write", row: 7, append: true });
  });

  it("rejects implausible prices and gaps", () => {
    expect(decidePriceWrite(rows, "2026-11", 21, "Manual")).toMatchObject({ action: "skip" });
    expect(decidePriceWrite(rows, "2026-08", 2.1, "Manual")).toMatchObject({ action: "skip" });
  });
});
