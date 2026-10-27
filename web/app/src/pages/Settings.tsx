import { useEffect, useMemo, useState } from "react";
import { AUTO_THEMES, FUEL_GRADES, THEMES, usageCount, type SettingsPatch, type StationEdit, type ThemeInfo } from "../../../shared/settings";
import type { DataResponse, Entry, SettingsWriteResponse } from "../../../shared/types";
import { api, useData, type WriteError } from "../data";
import { fmtAgo, fmtDate } from "../format";
import { useRouter } from "../router";
import { readDeviceTheme, writeDeviceTheme } from "../theme";
import { RemindersSection } from "./Reminders";

export function Settings() {
  const { data, error } = useData();
  if (!data) {
    return error ? (
      <section className="panel error-panel" role="alert">
        <h1 className="page-title">{error.message}</h1>
        <button type="button" className="btn" onClick={() => location.reload()}>
          {error.kind === "session" ? "Sign in again" : "Try again"}
        </button>
      </section>
    ) : (
      <p className="muted">Reading your sheet…</p>
    );
  }
  return <SettingsView data={data} />;
}

type Notice = { tone: "good" | "bad"; text: string } | null;

function SettingsView({ data }: { data: DataResponse }) {
  const { setData } = useData();
  const [notice, setNotice] = useState<Notice>(null);
  useEffect(() => {
    if (!notice) return;
    const id = setTimeout(() => setNotice(null), 8000);
    return () => clearTimeout(id);
  }, [notice]);

  async function save(call: () => Promise<SettingsWriteResponse>) {
    try {
      const res = await call();
      setData(res.data);
      setNotice({ tone: "good", text: res.message });
      return true;
    } catch (e) {
      const err = e as WriteError;
      if (err.data) setData(err.data);
      setNotice({ tone: "bad", text: err.message });
      return false;
    }
  }
  const putSettings = (patch: SettingsPatch) => save(() => api<SettingsWriteResponse>("/api/settings", { method: "PUT", body: { patch } }));

  return (
    <div className="dashboard settings">
      <div className="page-head">
        <h1 className="page-title">Settings</h1>
        <span className="page-sub mono">SAVED IN YOUR SHEET'S SETTINGS TAB</span>
      </div>
      {!data.canWrite && <div className="banner">Saving to your live sheet is locked, so settings can't be changed right now.</div>}

      <ThemeSection data={data} onSave={(theme) => putSettings({ theme })} />
      <CarSection data={data} onSave={putSettings} />
      <RemindersSection />
      <StationsSection data={data} onSave={(stations, renameInHistory) => save(() => api<SettingsWriteResponse>("/api/stations", { method: "PUT", body: { stations, renameInHistory } }))} />
      <DataSection data={data} />

      {notice && (
        // Fixed at the bottom so it's seen wherever the page is scrolled to.
        <div className={`toast${notice.tone === "bad" ? " toast--bad" : ""}`} role="status">
          <span>{notice.text}</span>
          <button type="button" className="btn btn--small" onClick={() => setNotice(null)}>
            OK
          </button>
        </div>
      )}
    </div>
  );
}

function ThemeSection({ data, onSave }: { data: DataResponse; onSave: (theme: string) => Promise<boolean> }) {
  const [device, setDevice] = useState(readDeviceTheme);
  const [busy, setBusy] = useState(false);
  const cluster = THEMES.find((t) => t.id === AUTO_THEMES.dark)!;
  const fintech = THEMES.find((t) => t.id === AUTO_THEMES.light)!;
  const options = [
    {
      id: "auto",
      name: "Auto",
      swatches: [cluster.swatches[0], cluster.swatches[2], fintech.swatches[0], fintech.swatches[2]] as ThemeInfo["swatches"],
      fonts: `${cluster.name} when your phone is dark, ${fintech.name} when light`,
      available: true,
    },
    ...THEMES,
  ];

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>Theme</h2>
        <span className="label">Everywhere you sign in</span>
      </div>
      <div className="themes" role="group" aria-label="Theme">
        {options.map((t) => (
          <button
            key={t.id}
            type="button"
            aria-pressed={data.settings.theme === t.id}
            className="theme-card"
            disabled={!t.available || !data.canWrite || busy}
            onClick={async () => {
              setBusy(true);
              await onSave(t.id);
              setBusy(false);
            }}
          >
            <span className="theme-card__swatches" aria-hidden="true">
              {t.swatches.map((c, i) => (
                <span key={i} style={{ background: c }} />
              ))}
            </span>
            <span className="theme-card__name">{t.name}</span>
            <span className="theme-card__note">{t.fonts}</span>
          </button>
        ))}
      </div>
      <label className="field field--inline">
        <span className="field__label">On this device</span>
        <select
          className="field__select"
          value={device ?? ""}
          onChange={(e) => {
            const v = e.target.value || null;
            writeDeviceTheme(v);
            setDevice(v);
          }}
        >
          <option value="">Same as everywhere</option>
          <option value="auto">Auto (dark/light)</option>
          {THEMES.filter((t) => t.available).map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </select>
      </label>
    </section>
  );
}

function CarSection({ data, onSave }: { data: DataResponse; onSave: (p: SettingsPatch) => Promise<boolean> }) {
  const s = data.settings;
  const [tank, setTank] = useState(String(s.tankCapacityL));
  const [grade, setGrade] = useState(s.fuelGrade);
  const [mode, setMode] = useState(s.defaultMode);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    setTank(String(s.tankCapacityL));
    setGrade(s.fuelGrade);
    setMode(s.defaultMode);
  }, [s.tankCapacityL, s.fuelGrade, s.defaultMode]);

  const tankNum = Number(tank.replace(",", "."));
  const tankValid = Number.isFinite(tankNum) && tankNum >= 20 && tankNum <= 150;
  const patch: SettingsPatch = {};
  if (tankValid && tankNum !== s.tankCapacityL) patch.tankCapacityL = tankNum;
  if (grade !== s.fuelGrade) patch.fuelGrade = grade;
  if (mode !== s.defaultMode) patch.defaultMode = mode;
  const dirty = Object.keys(patch).length > 0;

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>Car &amp; fuel</h2>
      </div>
      <div className="form-grid form-grid--2">
        <label className="field">
          <span className="field__label">Tank capacity · L</span>
          <input type="number" inputMode="decimal" value={tank} onChange={(e) => setTank(e.target.value)} aria-invalid={!tankValid} />
          {!tankValid && <span className="field__err">Between 20 and 150 L.</span>}
          {tankValid && tankNum !== s.tankCapacityL && <span className="field__warn">The sheet recalculates fuel used and L/100 km for every past fill-up with the new size.</span>}
        </label>
        <fieldset className="field field--row-phone">
          <legend className="field__label">Fuel grade · for WOQOD prices</legend>
          <div className="seg seg--wide">
            {FUEL_GRADES.map((g) => (
              <button key={g} type="button" className="seg__btn" aria-pressed={grade === g} onClick={() => setGrade(g)}>
                {g.toUpperCase()}
              </button>
            ))}
          </div>
        </fieldset>
        <fieldset className="field field--row-phone">
          <legend className="field__label">Default drive mode · Log form</legend>
          <div className="seg seg--wide">
            {s.modes.map((m) => (
              <button key={m} type="button" className="seg__btn" aria-pressed={mode === m} onClick={() => setMode(m)}>
                {m.toUpperCase()}
              </button>
            ))}
          </div>
        </fieldset>
      </div>
      <div className="form-actions form-actions--start">
        <button
          type="button"
          className="btn"
          disabled={!dirty || !tankValid || busy || !data.canWrite}
          onClick={async () => {
            setBusy(true);
            await onSave(patch);
            setBusy(false);
          }}
        >
          {busy ? "Saving…" : "Save car & fuel"}
        </button>
      </div>
    </section>
  );
}

const toEdits = (data: DataResponse): StationEdit[] =>
  (data.settings.stationList ?? data.settings.stations.map((name) => ({ name, archived: false }))).map((s) => ({ ...s, original: s.name }));

function StationsSection({ data, onSave }: { data: DataResponse; onSave: (s: StationEdit[], renameInHistory: boolean) => Promise<boolean> }) {
  const [rows, setRows] = useState<StationEdit[]>(() => toEdits(data));
  const [newName, setNewName] = useState("");
  const [renameInHistory, setRenameInHistory] = useState(true);
  const [busy, setBusy] = useState(false);
  useEffect(() => setRows(toEdits(data)), [data.settings.stationList]); // eslint-disable-line react-hooks/exhaustive-deps

  const unlisted = useMemo(() => {
    const names = new Set(data.settings.stationList.map((s) => s.name));
    return [...new Set(data.entries.map((e) => e.station).filter((s): s is string => !!s && !names.has(s)))];
  }, [data]);
  const dirty = JSON.stringify(rows) !== JSON.stringify(toEdits(data));
  const renamed = rows.filter((r) => r.original && r.original !== r.name.trim());
  const move = (i: number, by: number) =>
    setRows((rs) => {
      const next = [...rs];
      const [item] = next.splice(i, 1);
      next.splice(i + by, 0, item!);
      return next;
    });
  const used = (r: StationEdit) => (r.original ? usageCount(data.entries, r.original) : 0);

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>Gas stations</h2>
        <span className="label">Shown as quick picks on the Log form</span>
      </div>
      <ul className="stations">
        {rows.map((r, i) => (
          <li key={r.original ?? `new-${i}`} className={`station${r.archived ? " station--archived" : ""}`}>
            <input
              type="text"
              aria-label={`Station ${i + 1} name`}
              value={r.name}
              onChange={(e) => setRows((rs) => rs.map((x, j) => (j === i ? { ...x, name: e.target.value } : x)))}
            />
            <span className="station__count small muted">{used(r) ? `${used(r)} fill-up${used(r) === 1 ? "" : "s"}` : r.original ? "unused" : "new"}</span>
            <button type="button" className="icon-btn" aria-label={`Move ${r.name} up`} disabled={i === 0} onClick={() => move(i, -1)}>
              ↑
            </button>
            <button type="button" className="icon-btn" aria-label={`Move ${r.name} down`} disabled={i === rows.length - 1} onClick={() => move(i, 1)}>
              ↓
            </button>
            <button
              type="button"
              className="btn btn--ghost btn--small"
              aria-pressed={r.archived}
              onClick={() => setRows((rs) => rs.map((x, j) => (j === i ? { ...x, archived: !x.archived } : x)))}
            >
              {r.archived ? "Restore" : "Archive"}
            </button>
            <button
              type="button"
              className="icon-btn icon-btn--danger"
              aria-label={`Delete ${r.name}`}
              title={used(r) ? "Used by past fill-ups: archive it instead" : "Delete"}
              disabled={used(r) > 0}
              onClick={() => setRows((rs) => rs.filter((_, j) => j !== i))}
            >
              ×
            </button>
          </li>
        ))}
      </ul>
      <form
        className="station-add"
        onSubmit={(e) => {
          e.preventDefault();
          if (!newName.trim()) return;
          setRows((rs) => [...rs, { name: newName.trim(), archived: false }]);
          setNewName("");
        }}
      >
        <input type="text" placeholder="Add a station" aria-label="New station name" value={newName} onChange={(e) => setNewName(e.target.value)} />
        <button type="submit" className="btn btn--ghost" disabled={!newName.trim()}>
          Add
        </button>
      </form>
      {unlisted.length > 0 && (
        <p className="muted small">
          Used in past fill-ups but not in the list:{" "}
          {unlisted.map((n) => (
            <button key={n} type="button" className="link-btn" onClick={() => setRows((rs) => [...rs, { name: n, archived: false }])}>
              + {n}
            </button>
          ))}
        </p>
      )}
      {renamed.length > 0 && (
        <label className="check">
          <input type="checkbox" checked={renameInHistory} onChange={(e) => setRenameInHistory(e.target.checked)} />
          <span>
            Also rename in past fill-ups ({renamed.map((r) => `${r.original} → ${r.name.trim()}`).join(", ")})
          </span>
        </label>
      )}
      <div className="form-actions form-actions--start">
        <button type="button" className="btn btn--ghost" disabled={!dirty || busy} onClick={() => setRows(toEdits(data))}>
          Undo changes
        </button>
        <button
          type="button"
          className="btn"
          disabled={!dirty || busy || !data.canWrite}
          onClick={async () => {
            setBusy(true);
            await onSave(rows, renameInHistory);
            setBusy(false);
          }}
        >
          {busy ? "Saving…" : "Save stations"}
        </button>
      </div>
    </section>
  );
}

const csvCell = (v: string | number | boolean | null) => {
  const s = v == null ? "" : String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

function exportCsv(entries: Entry[]) {
  const head = ["Date", "Odometer (km)", "Litres", "Price (QAR/L)", "Total (QAR)", "Full", "Drive mode", "Station", "Distance (km)", "L/100 km", "QAR/km"];
  const lines = entries.map((e) =>
    [e.date, e.odometer, e.liters, e.pricePerLiter, e.totalCost, e.full, e.mode, e.station, e.distanceKm, e.litersPer100Km?.toFixed(2) ?? null, e.costPerKm?.toFixed(3) ?? null].map(csvCell).join(","),
  );
  const blob = new Blob([[head.join(","), ...lines].join("\n")], { type: "text/csv;charset=utf-8" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `oktan-fill-ups-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

function DataSection({ data }: { data: DataResponse }) {
  const { refresh, loading, setSheet } = useData();
  const { go } = useRouter();
  return (
    <section className="row">
      <div className="panel">
        <div className="panel-head">
          <h2>Data &amp; sync</h2>
        </div>
        <dl className="facts">
          <dt>Sheet</dt>
          <dd>
            <a href={data.sheetUrl} target="_blank" rel="noreferrer">
              {data.sheet === "live" ? "Qatar Fuel Tracking 2026" : "Oktan DEV (test copy)"} ↗
            </a>
          </dd>
          <dt>Last read</dt>
          <dd>{fmtAgo(data.fetchedAt)}</dd>
          <dt>Fill-ups</dt>
          <dd>
            {data.entries.length}
            {data.entries[0] && ` · since ${fmtDate(data.entries[0].date)}`}
          </dd>
        </dl>
        <div className="form-actions form-actions--start">
          <button type="button" className="btn btn--ghost" disabled={loading} onClick={refresh}>
            {loading ? "Refreshing…" : "Refresh now"}
          </button>
          <button type="button" className="btn btn--ghost" onClick={() => exportCsv(data.entries)}>
            Export CSV
          </button>
          <button
            type="button"
            className="btn btn--ghost"
            onClick={() => {
              try {
                sessionStorage.setItem("oktan:logTab", "prices");
              } catch {
                /* falls back to the first Log tab */
              }
              go("/log");
            }}
          >
            Fuel prices →
          </button>
        </div>
        {data.testModeAvailable && (
          <label className="check">
            <input type="checkbox" checked={data.sheet === "dev"} disabled={loading} onChange={(e) => setSheet(e.target.checked ? "dev" : "live")} />
            <span>Test mode: read and write the Oktan DEV copy instead of your real sheet</span>
          </label>
        )}
      </div>
      <div className="panel">
        <div className="panel-head">
          <h2>Account</h2>
        </div>
        <dl className="facts">
          <dt>Signed in as</dt>
          <dd>{data.email}</dd>
          <dt>Protected by</dt>
          <dd>Cloudflare Access · Google sign-in</dd>
          <dt>Home screen</dt>
          <dd>iPhone: Safari → Share → Add to Home Screen. You'll sign in with Google once inside the app.</dd>
        </dl>
        <div className="form-actions form-actions--start">
          <a className="btn btn--ghost" href="/cdn-cgi/access/logout">
            Sign out
          </a>
        </div>
      </div>
    </section>
  );
}
