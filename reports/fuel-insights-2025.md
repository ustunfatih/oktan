# Fuel Usage Insights (Sample Data)

This report summarizes the provided 2025 fuel log and outlines product ideas for the Oktan iOS app. The recommendations follow the Liquid Glass tone from the **iOS Design System** and the decision-simplifying patterns in **Laws of UX** (Fitts's Law for large CTAs, Hick's Law to keep choices lean, Von Restorff to highlight anomalies).

## Data Quality
- 11 fill-ups recorded; 10 have complete trip distances, and the last entry (2025-12-06) is missing odometer and trip distance.
- Some rows have empty drive mode; normalize to `Eco | Normal | Sport | Mixed` in the app.
- CSV now includes derived `Calc_L_per_100KM` and `Calc_Cost_per_KM` columns for the 10 complete trips; the incomplete row leaves them blank.

## Core Metrics (10 completed fill-ups)
- Total distance: **3,749 km**
- Fuel consumed (used liters): **398.41 L**
- Total fuel spend: **QR 797.09**
- Average efficiency: **10.63 L/100 km** (≈ 9.40 km/L)
- Average cost per km: **QR 0.213/km**

### Best and worst efficiency
- **Best:** 2025-04-28 (Eco) — **9.91 L/100 km**, QR 0.205/km.
- **Worst:** 2025-04-16 (mode unknown) — **12.47 L/100 km**, QR 0.256/km.

### Monthly spend (2025)
- Apr: QR 125.14 | May: QR 160.04 | Jul: QR 166.86 | Sep: QR 82.02 | Oct: QR 174.03 | Nov: QR 89.00 | Dec: (incomplete)

## Recommended KPIs for the app
- **Fuel efficiency:** L/100 km (primary), km/L (secondary). Use rolling 30/90-day averages for context.
- **Cost control:** Cost per km and cost per 100 km; monthly budget adherence with a progress ring.
- **Consistency:** Variance vs. personal baseline (e.g., ±10% from 30-day average). Highlight drops with the Von Restorff effect.
- **Drive mode impact:** Compare Eco vs. Normal vs. Sport efficiency and cost per km.
- **Station comparison:** Average L/100 km and QR/km per station (Pearl vs. Onaiza vs. Wadi Al Banat).
- **Seasonality:** Month-over-month efficiency deltas; show a soft seasonal slope line.
- **Trip mix:** Tag drives as City/Highway/Mixed and show per-tag efficiency.
- **CO₂ estimate:** Calculate kg CO₂ per km using fuel factors; surface as an optional insight.

## Chart and visualization ideas
- **Efficiency trend line:** L/100 km with 7-day smoothing; secondary line for cost/km. Touch target ≥44pt, high-contrast on translucent cards.
- **Drive mode comparison:** Segmented bars (Eco/Normal/Sport) for L/100 km and QR/km; keep ≤3 segments to respect Hick's Law.
- **Monthly spend stack:** Bars for fuel vs. maintenance tags; add budget threshold line.
- **Outlier spotlight:** Cards that glow for fill-ups deviating >10% from rolling average (Von Restorff effect).
- **Fuel-up detail card:** Liquid Glass card with large primary CTA (“Add Fill-Up”), secondary “More Details,” and chip tags for drive mode and station.

## Data model sketch
- **FillUp:** id, date, station, driveMode, odometerPre, odometerPost, litersAdded, pricePerLiter, totalCost, fuelInTankPre/Post (optional), isFull, contextTags.
- **Derived metrics:** distance = odometerPost − odometerPre; lPer100 = (usedLiters / distance) * 100; costPerKm = totalCost / distance.
- **Profiles:** vehicle (fuel type, tank size), budgets, alert thresholds.

## Insight rules to automate
- Flag fill-ups with **L/100 km > (rolling30 * 1.1)** and label “Inefficient trip — check tire pressure or traffic conditions.”
- If **cost/km** rises >8% week-over-week, suggest checking price changes by station.
- When **Eco** mode outperforms Sport by >0.6 L/100 km over 4 fill-ups, surface a “Eco wins” tip.

## Next steps for the iOS app
1. Build a **SwiftUI data layer** with Codable models and unit-tested metric calculators (pure functions for determinism).
2. Add **import/export** for CSV; validate required columns (date, odometer, liters, total cost, station or mode optional).
3. Ship an **“Add Fill-Up” flow**: minimal form, progressive disclosure for optional fields, bottom-aligned CTA.
4. Create a **Dashboard tab**: trend lines, budget ring, and insight cards with gentle, encouraging copy.
5. Implement **alerts** for outliers and budget overruns; allow per-user thresholds.

## Data table with computed metrics
- L/100 km and cost/km are derived using `Used_Fuel_L` when present; otherwise fall back to `Total_Litres`.

| Date       | Drive Mode | Station        | Distance (km) | Used (L) | L/100 km | Cost/km (QR) |
|------------|------------|----------------|---------------|----------|----------|--------------|
| 2025-04-16 | —          | —              | 157           | 19.58    | 12.47    | 0.256        |
| 2025-04-28 | Eco        | Pearl          | 414           | 41.03    | 9.91     | 0.205        |
| 2025-05-12 | Normal     | Pearl          | 379           | 41.04    | 10.83    | 0.211        |
| 2025-05-31 | Normal     | Pearl          | 401           | 40.86    | 10.19    | 0.200        |
| 2025-07-06 | Normal     | Onaiza         | 409           | 42.57    | 10.41    | 0.200        |
| 2025-07-20 | Sport      | Pearl          | 357           | 41.01    | 11.49    | 0.238        |
| 2025-09-10 | Sport      | Pearl          | 373           | 42.94    | 11.51    | 0.220        |
| 2025-10-11 | Normal     | Pearl          | 419           | 41.95    | 10.01    | 0.210        |
| 2025-10-27 | Normal     | Pearl          | 412           | 44.50    | 10.80    | 0.209        |
| 2025-11-19 | Eco        | Pearl          | 428           | 42.93    | 10.03    | 0.208        |
| 2025-12-06 | Eco        | Wadi Al Banat  | —             | 42.93    | —        | —            |

