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

export interface SummaryResponse {
  email: string;
  sheet: "live" | "dev";
  summary: Summary;
  latest: Entry | null;
  lastClosed: Entry | null;
}
