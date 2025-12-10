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
