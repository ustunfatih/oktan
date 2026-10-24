import type { Entry } from "./types";

/**
 * The Data tab's columns A–P, in order. Matching is whitespace- and case-insensitive,
 * so the header's line breaks ("Odometer\nPRE") don't matter.
 */
export const EXPECTED_HEADERS = [
  "Date",
  "Odometer PRE",
  "Odometer POST",
  "Total L",
  "Price per L",
  "Total Fuel Cost",
  "Full?",
  "Drive Mode",
  "Gas Station",
  "Driven KM",
  "Used FUEL",
  "Fuel in Tank PRE",
  "Fuel in Tank POST",
  "100 KM/L",
  "Cost per KM",
  "ID",
] as const;

export class SheetLayoutError extends Error {}

type Cell = string | number | boolean | null | undefined;

const normalize = (s: Cell) => String(s ?? "").replace(/\s+/g, " ").trim().toLowerCase();

/** Throws if the header row no longer matches the layout the app reads and writes. */
export function checkHeaders(header: Cell[]): void {
  const problems = EXPECTED_HEADERS.flatMap((expected, i) =>
    normalize(header[i]) === normalize(expected)
      ? []
      : [`column ${String.fromCharCode(65 + i)}: expected "${expected}", found "${header[i] ?? ""}"`],
  );
  if (problems.length) throw new SheetLayoutError(`Data tab layout changed — ${problems.join("; ")}`);
}

/** Google Sheets date serial (days since 1899-12-30) to YYYY-MM-DD. */
export function serialToIsoDate(serial: number): string {
  const ms = Math.round((serial - 25569) * 86_400_000);
  return new Date(ms).toISOString().slice(0, 10);
}

const num = (v: Cell): number | null => (typeof v === "number" && Number.isFinite(v) ? v : null);
const text = (v: Cell): string | null => {
  const s = String(v ?? "").trim();
  return s ? s : null;
};

/**
 * Turns the Data tab's values (read with UNFORMATTED_VALUE and SERIAL_NUMBER dates, header included)
 * into entries. Rows without a date are skipped.
 */
export function parseEntries(values: Cell[][]): Entry[] {
  const [header, ...rows] = values;
  checkHeaders(header ?? []);
  const entries: Entry[] = [];
  rows.forEach((r, i) => {
    const date = num(r[0]);
    if (date === null) return;
    entries.push({
      id: text(r[15]) ?? `row-${i + 2}`,
      row: i + 2,
      date: serialToIsoDate(date),
      odometer: num(r[1]),
      odometerEnd: num(r[2]),
      liters: num(r[3]) ?? 0,
      pricePerLiter: num(r[4]),
      totalCost: num(r[5]),
      full: r[6] === true,
      mode: text(r[7]),
      station: text(r[8]),
      distanceKm: num(r[9]),
      usedFuelL: num(r[10]),
      litersPer100Km: num(r[13]),
      costPerKm: num(r[14]),
    });
  });
  return entries;
}
