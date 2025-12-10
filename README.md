# oktan

Benzin takip uygulaması

## Web preview

You can view the Markdown reports (for example `reports/fuel-insights-2025.md`) in a browser without any extra build steps.

1. From the repo root, start a tiny static server:
   ```bash
   python -m http.server 8000
   ```
2. Open `http://localhost:8000/reports/fuel-insights-2025.md` in your browser to read the report. The file stays in sync with the repo—refresh after edits.

If you prefer GitHub-like styling, install Grip once (`pip install grip`) and run:
```bash
grip reports/fuel-insights-2025.md 8000
```
Then open `http://localhost:8000` to see a styled preview. Stop the server with `Ctrl+C` when you’re done.

## iOS app blueprint (Tracking + Reporting)

The SwiftUI app lives in `ios/` and follows the Liquid Glass design language and Laws of UX.

- **Tracking tab** – manual fuel entry with date, liters, price/litre, drive mode, gas station, and optional odometer start/end. Distance, total cost, L/100 km, and cost/km are derived automatically when both odometer values are present.
- **Reporting tab** – aggregated totals (distance, liters, cost), efficiency (L/100 km), cost per km, recent rolling averages, and drive-mode deltas. Charts use Apple’s Charts framework.
- **Data model** – `FuelEntry` + `FuelRepository` handle validation, persistence (JSON in Documents), seeding from the sample log, and summarization.
- **Design system** – SF Pro type scale, 8/16/24pt spacing, `.ultraThinMaterial` glass cards, Primary Blue accents, and ≥44pt tap targets per the iOS design doc.

To explore the UI, open `ios/` in Xcode 16+, target iOS 17, and run the `OktanApp` scheme. The seed data mirrors `data/fuel-log-sample.csv` so Reports immediately show trends.

### iOS previews

- **SwiftUI canvas**: Open `OktanApp.swift`, `TrackingView.swift`, or `ReportsView.swift` in Xcode and tap the canvas Play button (or press `⌥⌘P`). Previews use the seeded repository so you immediately see charts and metrics. If the preview gets stuck, choose **Editor > Canvas > Refresh Canvas**.
- **Simulator/device**: Select an iPhone 15 (or later) simulator and run the `OktanApp` scheme. On first launch, the sample log is imported automatically; adding new fill-ups updates the Reports tab in real time.
- **Accessibility check**: In the simulator, turn on **Settings > Accessibility > Display & Text Size > Larger Text** to verify dynamic type. All tappable controls meet the ≥44pt target specified in the design docs.
- **No-build visual check**: If you just want to eyeball the layout without compiling the full app, open `TrackingView.swift` or `ReportsView.swift`, ensure the canvas shows the correct preview device (iPhone 15), then click **Resume**. Xcode renders the glass cards, charts, and typography directly from the SwiftUI preview providers—no target build required.
