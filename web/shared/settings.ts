import type { Entry, Settings, StationItem } from "./types";

export interface ThemeInfo {
  id: string;
  name: string;
  /** Background, panel, accent, second accent: shown as swatches in the picker. */
  swatches: [string, string, string, string];
  fonts: string;
  /** False hides a theme from the picker (kept for themes still in progress). */
  available: boolean;
}

export const THEMES: ThemeInfo[] = [
  { id: "cluster", name: "Instrument Cluster", swatches: ["#0A0C0F", "#11151A", "#FFB547", "#4FD1E8"], fonts: "Chakra Petch + JetBrains Mono", available: true },
  { id: "swiss", name: "Swiss Ledger", swatches: ["#FFFFFF", "#F2F2F2", "#111111", "#E30613"], fonts: "Inter Tight + IBM Plex Mono", available: true },
  { id: "doha", name: "Doha Editorial", swatches: ["#F6F1E9", "#FFFDF9", "#8A1538", "#1F6F6B"], fonts: "Fraunces + Work Sans", available: true },
  { id: "fintech", name: "Soft Fintech", swatches: ["#F4F6FB", "#FFFFFF", "#4F46E5", "#10B981"], fonts: "Plus Jakarta Sans + DM Mono", available: true },
  { id: "brutalist", name: "Pump Brutalist", swatches: ["#FFF8E7", "#FFFFFF", "#FFD60A", "#1F4FFF"], fonts: "Space Grotesk + Space Mono", available: true },
];

export const THEME_IDS = ["auto", ...THEMES.map((t) => t.id)];
export const FUEL_GRADES = ["Super 95", "Premium 91", "Diesel"];

/** Themes "auto" switches between, following the phone's dark/light setting. */
export const AUTO_THEMES = { dark: "cluster", light: "fintech" } as const;

/** The theme to actually show: a device override wins; "auto" follows dark/light; unknown falls back to Cluster. */
export function resolveTheme(sheetTheme: string, deviceTheme: string | null, prefersDark = true): string {
  const pick = deviceTheme || sheetTheme;
  if (pick === "auto") return prefersDark ? AUTO_THEMES.dark : AUTO_THEMES.light;
  return THEMES.find((t) => t.id === pick && t.available)?.id ?? "cluster";
}

export type SettingsPatch = Partial<Pick<Settings, "theme" | "fuelGrade" | "tankCapacityL" | "defaultMode">>;
export type SettingsErrors = Partial<Record<keyof SettingsPatch | "stations", string>>;

export function validateSettings(patch: SettingsPatch, modes: string[]): SettingsErrors {
  const e: SettingsErrors = {};
  if (patch.theme !== undefined && !THEME_IDS.includes(patch.theme)) e.theme = "Unknown theme.";
  if (patch.fuelGrade !== undefined && !FUEL_GRADES.includes(patch.fuelGrade)) e.fuelGrade = "Pick Super 95, Premium 91 or Diesel.";
  if (patch.tankCapacityL !== undefined && (!Number.isFinite(patch.tankCapacityL) || patch.tankCapacityL < 20 || patch.tankCapacityL > 150))
    e.tankCapacityL = "Tank capacity should be between 20 and 150 L.";
  if (patch.defaultMode !== undefined && !modes.includes(patch.defaultMode)) e.defaultMode = "Pick one of your drive modes.";
  return e;
}

/** A row of the station editor: `original` is the name it had when the page loaded (undefined = new). */
export interface StationEdit extends StationItem {
  original?: string;
}

export interface StationsPlan {
  list: StationItem[];
  /** Renames to apply to past fill-ups (only when the user asked for it). */
  renames: { from: string; to: string }[];
}

/**
 * Checks an edited station list against the sheet:
 * names must be unique and non-empty, and a station still used by a fill-up can be archived but not removed.
 */
export function planStations(current: StationItem[], edits: StationEdit[], entries: Entry[], renameInHistory: boolean): StationsPlan {
  const clean = edits.map((s) => ({ ...s, name: s.name.trim() }));
  const blank = clean.find((s) => !s.name);
  if (blank) throw new Error("Station names can't be empty.");
  const long = clean.find((s) => s.name.length > 60);
  if (long) throw new Error(`"${long.name.slice(0, 20)}…" is too long; keep names under 60 characters.`);
  const seen = new Set<string>();
  for (const s of clean) {
    const k = s.name.toLowerCase();
    if (seen.has(k)) throw new Error(`"${s.name}" is in the list twice.`);
    seen.add(k);
  }

  const renames = clean.filter((s) => s.original && s.original !== s.name).map((s) => ({ from: s.original!, to: s.name }));
  const kept = new Set(clean.map((s) => s.original ?? s.name));
  for (const old of current) {
    if (kept.has(old.name)) continue;
    const used = entries.filter((e) => e.station === old.name).length;
    if (used) throw new Error(`"${old.name}" is used by ${used} fill-up${used === 1 ? "" : "s"}; archive it instead of deleting it.`);
  }
  if (!renameInHistory) {
    // Renaming without touching history would leave old fill-ups pointing at a name no longer in the list.
    for (const r of renames) {
      const used = entries.filter((e) => e.station === r.from).length;
      if (used) throw new Error(`"${r.from}" is used by ${used} fill-up${used === 1 ? "" : "s"}. Tick "also rename in past fill-ups", or add "${r.to}" as a new station.`);
    }
  }
  return { list: clean.map(({ name, archived }) => ({ name, archived })), renames: renameInHistory ? renames : [] };
}

export const usageCount = (entries: Entry[], name: string) => entries.filter((e) => e.station === name).length;
