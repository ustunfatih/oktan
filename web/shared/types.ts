export type DriveMode = "Eco" | "Normal" | "Sport";

/** One fill-up, i.e. one row of the sheet's Data tab. */
export interface Entry {
  /** Stable ID from the hidden column P. */
  id: string;
  /** 1-based row number in the Data tab (row 1 is the header). */
  row: number;
  /** Fill-up date as YYYY-MM-DD. */
  date: string;
  /** Odometer reading at this fill-up (column B). */
  odometer: number | null;
  /** Odometer reading at the next fill-up (column C); null while the trip is open. */
  odometerEnd: number | null;
  liters: number;
  pricePerLiter: number | null;
  totalCost: number | null;
  full: boolean;
  mode: DriveMode | string | null;
  station: string | null;
  /** Trip that starts at this fill-up. Null while it is still open. */
  distanceKm: number | null;
  usedFuelL: number | null;
  litersPer100Km: number | null;
  costPerKm: number | null;
}

/** One row of the Fuel Prices tab. */
export interface MonthPrice {
  /** YYYY-MM */
  month: string;
  price: number | null;
  /** "WOQOD", "Manual" or "Sheet"; null when not recorded. */
  source: string | null;
}

export interface StationItem {
  name: string;
  /** Archived stations stay in the sheet's list (for old fill-ups) but are hidden from the Log form. */
  archived: boolean;
}

/** The Settings tab. */
export interface Settings {
  theme: string;
  fuelGrade: string;
  tankCapacityL: number;
  defaultMode: string;
  currency: string;
  /** Active station names, in the sheet's order. */
  stations: string[];
  /** Every station in the list, archived ones included. */
  stationList: StationItem[];
  modes: string[];
}

export interface DataResponse {
  email: string;
  sheet: "live" | "dev";
  /** False while writing to the live sheet is still locked. */
  canWrite: boolean;
  /** True when the Worker knows the DEV copy, so the app can offer test mode. */
  testModeAvailable: boolean;
  /** Link to the Google Sheet this response came from. */
  sheetUrl: string;
  /** ISO timestamp of the sheet read (may be up to the cache TTL old). */
  fetchedAt: string;
  entries: Entry[];
  prices: MonthPrice[];
  settings: Settings;
}

export interface WoqodPrice {
  /** e.g. "Gasoline Super (95)" */
  grade: string;
  price: number;
  /** YYYY-MM the price applies to */
  month: string;
}

export type WoqodResponse =
  | { ok: true; prices: WoqodPrice[]; fetchedAt: string }
  | { ok: false; error: string };

export interface Summary {
  fillUps: number;
  closedTrips: number;
  distanceKm: number;
  totalLiters: number;
  totalSpend: number;
  /** Distance-weighted: 100 × total used fuel ÷ total distance. */
  litersPer100Km: number | null;
  costPerKm: number | null;
  avgKmPerTank: number | null;
}

/** Response to a successful add, edit or delete: the fresh sheet plus where the change landed. */
export interface WriteResponse {
  data: DataResponse;
  result: { id: string; row: number | null };
}

/** Response to a price change: the fresh sheet plus what happened (a skip is not an error). */
export interface PriceWriteResponse {
  data: DataResponse;
  outcome: { written: boolean; message: string; month?: string; price?: number };
}

/** Response to a settings or station-list change. */
export interface SettingsWriteResponse {
  data: DataResponse;
  message: string;
}
