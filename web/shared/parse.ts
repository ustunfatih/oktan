import type { Entry, MonthPrice, Settings } from "./types";

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

export type Cell = string | number | boolean | null | undefined;

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

/** The Fuel Prices tab's B:D block (header "Month, Price, Source" included). Rows without a month are skipped. */
export function parsePrices(values: Cell[][]): MonthPrice[] {
  return values.slice(1).flatMap((r) => {
    const serial = num(r[0]);
    if (serial === null) return [];
    return [{ month: serialToIsoDate(serial).slice(0, 7), price: num(r[1]), source: text(r[2]) }];
  });
}

export const SETTING_KEYS: Record<string, keyof Omit<Settings, "stations" | "stationList" | "modes">> = {
  theme: "theme",
  "fuel grade": "fuelGrade",
  "tank capacity (l)": "tankCapacityL",
  "default drive mode": "defaultMode",
  currency: "currency",
};

export const DEFAULT_SETTINGS: Settings = {
  theme: "auto",
  fuelGrade: "Super 95",
  tankCapacityL: 47,
  defaultMode: "Eco",
  currency: "QAR",
  stations: [],
  stationList: [],
  modes: ["Eco", "Normal", "Sport"],
};

/** The Settings tab's A:G block: key/value pairs in A:B, stations in E (archived flag in F), drive modes in G. */
export function parseSettings(values: Cell[][]): Settings {
  const s: Settings = { ...DEFAULT_SETTINGS, stations: [], stationList: [], modes: [] };
  for (const r of values.slice(1)) {
    const key = SETTING_KEYS[normalize(r[0])];
    if (key === "tankCapacityL") s.tankCapacityL = num(r[1]) ?? DEFAULT_SETTINGS.tankCapacityL;
    else if (key) s[key] = text(r[1]) ?? DEFAULT_SETTINGS[key];
    const station = text(r[4]);
    if (station) {
      const archived = r[5] === true || normalize(r[5]) === "true";
      s.stationList.push({ name: station, archived });
      if (!archived) s.stations.push(station);
    }
    const mode = text(r[6]);
    if (mode) s.modes.push(mode);
  }
  if (!s.modes.length) s.modes = [...DEFAULT_SETTINGS.modes];
  return s;
}
