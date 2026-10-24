import type { Entry, Summary } from "./types";

const isClosed = (e: Entry): e is Entry & { distanceKm: number; usedFuelL: number } =>
  e.distanceKm !== null && e.distanceKm > 0 && e.usedFuelL !== null;

export function summarize(entries: Entry[]): Summary {
  const closed = entries.filter(isClosed);
  const distanceKm = closed.reduce((s, e) => s + e.distanceKm, 0);
  const usedFuel = closed.reduce((s, e) => s + e.usedFuelL, 0);
  const fuelCost = closed.reduce((s, e) => s + e.usedFuelL * (e.pricePerLiter ?? 0), 0);
  return {
    fillUps: entries.length,
    closedTrips: closed.length,
    distanceKm,
    totalLiters: entries.reduce((s, e) => s + e.liters, 0),
    totalSpend: entries.reduce((s, e) => s + (e.totalCost ?? 0), 0),
    litersPer100Km: distanceKm > 0 ? (100 * usedFuel) / distanceKm : null,
    costPerKm: distanceKm > 0 ? fuelCost / distanceKm : null,
    avgKmPerTank: closed.length ? distanceKm / closed.length : null,
  };
}

export const latestEntry = (entries: Entry[]): Entry | null => entries.at(-1) ?? null;

export const lastClosedEntry = (entries: Entry[]): Entry | null => entries.findLast(isClosed) ?? null;
