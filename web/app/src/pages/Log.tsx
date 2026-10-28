import { useEffect, useMemo, useRef, useState } from "react";
import { woqodForGrade } from "../../../shared/prices";
import type { DataResponse, Entry, PriceWriteResponse, WoqodResponse, WriteResponse } from "../../../shared/types";
import { deleteConsequence, type EntryInput } from "../../../shared/writes";
import { api, useData, useWoqod, type WriteError } from "../data";
import { fmt, fmtDate, fmtMonthLong, qar, qatarToday } from "../format";
import { reduceMotion } from "../motion";
import { EntryForm } from "./EntryForm";

type Tab = "new" | "history" | "prices";
type Toast = { text: string; undo?: () => Promise<void> };

const toInput = (e: Entry): EntryInput => ({
  date: e.date,
  odometer: e.odometer ?? 0,
  liters: e.liters,
  pricePerLiter: e.pricePerLiter ?? 0,
  totalCost: e.totalCost ?? 0,
  full: e.full,
  mode: e.mode ?? "Eco",
  station: e.station ?? "",
});

export function Log() {
  const { data, error, setData, setSheet, loading, pending, sendPending, discardPending } = useData();
  const woqod = useWoqod();
  const [tab, setTab] = useState<Tab>(() => {
    // Settings → "Fuel prices" opens this tab on Prices.
    try {
      const wanted = sessionStorage.getItem("oktan:logTab");
      sessionStorage.removeItem("oktan:logTab");
      return wanted === "prices" ? "prices" : "new";
    } catch {
      return "new";
    }
  });
  const [editing, setEditing] = useState<Entry | null>(null);
  const [toast, setToast] = useState<Toast | null>(null);
  const [formKey, setFormKey] = useState(0);
  const timer = useRef<number | undefined>(undefined);

  useEffect(() => () => clearTimeout(timer.current), []);
  const notify = (t: Toast) => {
    setToast(t);
    clearTimeout(timer.current);
    timer.current = window.setTimeout(() => setToast(null), 15_000);
  };

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

  const onSaved = (res: WriteResponse, previous: Entry | null) => {
    setData(res.data);
    setEditing(null);
    setFormKey((k) => k + 1);
    if (previous) {
      notify({
        text: `Updated the ${fmtDate(previous.date)} fill-up.`,
        undo: async () => {
          const now = res.data.entries.find((e) => e.id === previous.id);
          if (!now) return;
          const r = await api<WriteResponse>(`/api/entries/${previous.id}`, { method: "PUT", body: { entry: toInput(previous), rowSeen: now.row } });
          setData(r.data);
        },
      });
    } else {
      const added = res.data.entries.find((e) => e.id === res.result.id);
      notify({
        text: `Saved to row ${res.result.row}.`,
        undo: async () => {
          if (!added) return;
          const r = await api<WriteResponse>(`/api/entries/${added.id}`, { method: "DELETE", body: { rowSeen: added.row } });
          setData(r.data);
        },
      });
    }
  };

  return (
    <div className="dashboard log">
      <div className="page-head page-head--tabs">
        <h1 className="page-title">Log</h1>
        <div className="seg" role="group" aria-label="Log sections">
          {(
            [
              ["new", editing ? "EDIT" : "NEW FILL-UP"],
              ["history", "HISTORY"],
              ["prices", "PRICES"],
            ] as [Tab, string][]
          ).map(([id, label]) => (
            <button key={id} type="button" className="seg__btn" aria-pressed={tab === id} onClick={() => setTab(id)}>
              {label}
            </button>
          ))}
        </div>
      </div>

      <SheetBanner data={data} loading={loading} onSwitch={setSheet} />

      {pending.length > 0 && (
        <section className="panel waiting" role="status" aria-label="Fill-ups waiting to send">
          <div className="panel-head">
            <h2>Waiting to send</h2>
            <span className="label">
              {pending.length} saved on this phone
            </span>
          </div>
          <ul className="history">
            {pending.map((q) => (
              <li key={q.id} className="history__item">
                <div className="history__row">
                  <div className="history__main">
                    <div className="mono">
                      {fmtDate(q.entry.date)} · {q.entry.station || "—"}
                    </div>
                    <div className="muted small">
                      {fmt(q.entry.liters, 2)} L · {qar(q.entry.totalCost)}
                      {q.error ? ` · not sent: ${q.error}` : ""}
                    </div>
                  </div>
                  <button type="button" className="btn btn--ghost btn--small" onClick={() => discardPending(q.id)}>
                    Discard
                  </button>
                </div>
              </li>
            ))}
          </ul>
          <div className="form-actions form-actions--start">
            <button type="button" className="btn btn--small" onClick={sendPending}>
              Send now
            </button>
          </div>
        </section>
      )}

      {tab === "new" && (
        <section className="panel log-panel">
          <div className="panel-head">
            <h2>{editing ? `Edit the ${fmtDate(editing.date)} fill-up` : "New fill-up"}</h2>
            {!editing && data.entries.at(-1) && (
              <span className="label">
                Previous: {fmtDate(data.entries.at(-1)!.date)} · {fmt(data.entries.at(-1)!.odometer)} km
              </span>
            )}
          </div>
          <EntryForm
            key={`${formKey}-${editing?.id ?? "new"}-${data.sheet}`}
            data={data}
            woqod={woqod}
            editing={editing ?? undefined}
            onSaved={onSaved}
            onQueued={() => {
              setFormKey((k) => k + 1);
              notify({ text: "You're offline. Saved on this phone; it will go to the sheet when you're back online." });
            }}
            onConflict={setData}
            onCancel={
              editing
                ? () => {
                    setEditing(null);
                    setTab("history");
                  }
                : undefined
            }
          />
        </section>
      )}

      {tab === "history" && (
        <History
          data={data}
          onEdit={(e) => {
            setEditing(e);
            setTab("new");
            scrollTo({ top: 0 });
          }}
          onDeleted={(res, removed) => {
            setData(res.data);
            notify({ text: `Deleted the ${fmtDate(removed.date)} fill-up. It's recorded in the sheet's App_Log tab.` });
          }}
          onConflict={setData}
        />
      )}

      {tab === "prices" && <Prices data={data} woqod={woqod} onData={setData} notify={notify} />}

      {toast && (
        <div className="toast" role="status">
          <span>{toast.text}</span>
          {toast.undo && (
            <button
              type="button"
              className="btn btn--small"
              onClick={async () => {
                const undo = toast.undo!;
                setToast(null);
                try {
                  await undo();
                  notify({ text: "Undone." });
                } catch (e) {
                  notify({ text: `Couldn't undo: ${(e as WriteError).message}` });
                }
              }}
            >
              Undo
            </button>
          )}
        </div>
      )}
    </div>
  );
}

function SheetBanner({ data, loading, onSwitch }: { data: DataResponse; loading: boolean; onSwitch: (s: "live" | "dev") => Promise<void> }) {
  if (data.sheet === "dev" && data.testModeAvailable) {
    return (
      <div className="banner banner--test" role="status">
        <span>
          <b>Test mode.</b> You're reading and writing the Oktan DEV copy; your real sheet isn't touched.
        </span>
        <button type="button" className="btn btn--small" disabled={loading} onClick={() => onSwitch("live")}>
          Back to live
        </button>
      </div>
    );
  }
  if (data.sheet === "dev") {
    return (
      <div className="banner banner--test" role="status">
        <span>
          <b>Local development:</b> reading and writing the Oktan DEV copy.
        </span>
      </div>
    );
  }
  if (!data.canWrite) {
    return (
      <div className="banner" role="status">
        <span>
          Saving to your <b>live sheet</b> is locked until you've approved the test.{data.testModeAvailable ? " Try everything safely in test mode first." : ""}
        </span>
        {data.testModeAvailable && (
          <button type="button" className="btn btn--small" disabled={loading} onClick={() => onSwitch("dev")}>
            Test mode
          </button>
        )}
      </div>
    );
  }
  return null;
}

function History({
  data,
  onEdit,
  onDeleted,
  onConflict,
}: {
  data: DataResponse;
  onEdit: (e: Entry) => void;
  onDeleted: (res: WriteResponse, removed: Entry) => void;
  onConflict: (d: DataResponse) => void;
}) {
  const [confirming, setConfirming] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const list = [...data.entries].reverse();

  async function remove(e: Entry) {
    setBusy(true);
    setErr(null);
    try {
      const res = await api<WriteResponse>(`/api/entries/${e.id}`, { method: "DELETE", body: { rowSeen: e.row } });
      setConfirming(null);
      onDeleted(res, e);
    } catch (x) {
      const w = x as WriteError;
      setErr(w.message);
      if (w.data) onConflict(w.data);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>History</h2>
        <span className="label">{data.entries.length} fill-ups · newest first</span>
      </div>
      {err && (
        <p className="form-error" role="alert">
          {err}
        </p>
      )}
      <ul className="history">
        {list.map((e) => (
          <li key={e.id} className="history__item">
            <div className="history__row">
              <div className="history__main">
                <div className="mono">
                  {fmtDate(e.date)} · {e.station ?? "—"}
                </div>
                <div className="muted small">
                  {fmt(e.liters, 2)} L · {qar(e.totalCost)} · {e.mode ?? "—"}
                  {e.distanceKm === null ? " · trip open" : ` · ${fmt(e.distanceKm)} km · ${fmt(e.litersPer100Km, 2)} L/100`}
                </div>
              </div>
              <button type="button" className="icon-btn" aria-label={`Edit the ${fmtDate(e.date)} fill-up`} disabled={!data.canWrite} onClick={() => onEdit(e)}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden="true">
                  <path d="M4 20v-4L15 5l4 4L8 20Z" />
                </svg>
              </button>
              <button
                type="button"
                className="icon-btn icon-btn--danger"
                aria-label={`Delete the ${fmtDate(e.date)} fill-up`}
                disabled={!data.canWrite}
                onClick={() => setConfirming(confirming === e.id ? null : e.id)}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden="true">
                  <path d="M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13" />
                </svg>
              </button>
            </div>
            {confirming === e.id && (
              <div className="confirm" role="alertdialog" aria-label="Confirm delete">
                <p>
                  Delete the {fmtDate(e.date)} fill-up? {deleteConsequence(data.entries, e.id, fmtDate)}
                </p>
                <div className="confirm__actions">
                  <button type="button" className="btn btn--ghost btn--small" onClick={() => setConfirming(null)}>
                    Cancel
                  </button>
                  <button type="button" className="btn btn--danger btn--small" disabled={busy} onClick={() => remove(e)}>
                    {busy ? "Deleting…" : "Delete"}
                  </button>
                </div>
              </div>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}

function Prices({
  data,
  woqod,
  onData,
  notify,
}: {
  data: DataResponse;
  woqod: WoqodResponse | null;
  onData: (d: DataResponse) => void;
  notify: (t: Toast) => void;
}) {
  const today = qatarToday();
  const thisMonth = today.slice(0, 7);
  const months = useMemo(() => {
    const [y, m] = thisMonth.split("-").map(Number) as [number, number];
    return Array.from({ length: 14 }, (_, i) => {
      const d = new Date(Date.UTC(y, m - 1 + 1 - i, 1));
      return d.toISOString().slice(0, 7);
    });
  }, [thisMonth]);
  const [month, setMonth] = useState(thisMonth);
  const [price, setPrice] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const mine = woqod?.ok ? woqodForGrade(woqod.prices, data.settings.fuelGrade) : null;
  const saved = (m: string) => data.prices.find((p) => p.month === m) ?? null;
  const sheetForWoqod = mine ? saved(mine.month) : null;
  const shown = data.prices.filter((p) => p.month <= months[0]! && (p.price !== null || p.month >= thisMonth)).slice(-14).reverse();

  // Pre-fill the price field with what the selected month already has (or a sensible suggestion).
  useEffect(() => {
    const existing = saved(month)?.price;
    setPrice(existing != null ? existing.toFixed(2) : mine && mine.month === month ? mine.price.toFixed(2) : "");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [month, data.prices]);

  async function run(key: string, call: () => Promise<PriceWriteResponse>) {
    setBusy(key);
    setErr(null);
    try {
      const res = await call();
      onData(res.data);
      notify({ text: res.outcome.message });
    } catch (e) {
      setErr((e as WriteError).message);
    } finally {
      setBusy(null);
    }
  }
  const refresh = () => run("refresh", () => api<PriceWriteResponse>("/api/prices/refresh", { method: "POST", body: {} }));
  const saveManual = () => run("manual", () => api<PriceWriteResponse>(`/api/prices/${month}`, { method: "PUT", body: { price: Number(price.replace(",", ".")) } }));
  const unlock = (m: string) => run(`unlock-${m}`, () => api<PriceWriteResponse>(`/api/prices/${m}/unlock`, { method: "POST", body: {} }));
  const priceNum = Number(price.replace(",", "."));
  const priceValid = Number.isFinite(priceNum) && priceNum >= 0.5 && priceNum <= 5;

  let status: { tone: "good" | "warn" | "info"; text: string } | null = null;
  if (mine) {
    if (!sheetForWoqod?.price) status = { tone: "warn", text: `Not in your sheet yet. The monthly check saves it automatically, or save it now.` };
    else if (sheetForWoqod.source === "Manual")
      status = { tone: "info", text: `Your sheet has a manual price of QAR ${sheetForWoqod.price.toFixed(2)} for ${fmtMonthLong(mine.month)}, which stays locked.` };
    else if (Math.abs(sheetForWoqod.price - mine.price) > 0.0005) status = { tone: "warn", text: `Your sheet says QAR ${sheetForWoqod.price.toFixed(2)}. Saving will update it.` };
    else status = { tone: "good", text: `Saved in your sheet${sheetForWoqod.source === "WOQOD" ? " from WOQOD" : ""}.` };
  }

  return (
    <>
      <section className="panel">
        <div className="panel-head">
          <h2>WOQOD this month</h2>
          <span className="label">{data.settings.fuelGrade}</span>
        </div>
        {mine ? (
          <div className="price price--mine">
            <div>
              <div className="price__grade">{fmtMonthLong(mine.month)}</div>
              <div className="price__note">{mine.grade}</div>
            </div>
            <div className="price__value mono">{mine.price.toFixed(2)}</div>
          </div>
        ) : (
          <p className="muted">{woqod ? (woqod.ok ? `WOQOD has no ${data.settings.fuelGrade} price.` : `WOQOD unavailable: ${woqod.error}`) : "Checking WOQOD…"}</p>
        )}
        {status && <p className={`insight insight--${status.tone}`}>{status.text}</p>}
        <div className="form-actions form-actions--start">
          <button type="button" className="btn" disabled={!data.canWrite || busy !== null} onClick={refresh}>
            {busy === "refresh" ? "Fetching…" : "Fetch from WOQOD and save"}
          </button>
        </div>
        <p className="muted small">Checked automatically at 06:00 on the 1st–5th of every month. Manual prices are never overwritten.</p>
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>Set a price by hand</h2>
          <span className="label">Locked once saved</span>
        </div>
        <div className="form-grid form-grid--2">
          <label className="field">
            <span className="field__label">Month</span>
            <select className="field__select" value={month} onChange={(e) => setMonth(e.target.value)}>
              {months.map((m) => (
                <option key={m} value={m}>
                  {fmtMonthLong(m)}
                  {saved(m)?.price != null ? ` · ${saved(m)!.price!.toFixed(2)}` : ""}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span className="field__label">{data.settings.fuelGrade} · QAR/L</span>
            <input type="number" inputMode="decimal" step="0.01" value={price} onChange={(e) => setPrice(e.target.value)} aria-invalid={price !== "" && !priceValid} />
            {price !== "" && !priceValid && <span className="field__err">Prices in Qatar are between QAR 0.50 and 5.00.</span>}
          </label>
        </div>
        <div className="form-actions form-actions--start">
          <button type="button" className="btn" disabled={!data.canWrite || !priceValid || busy !== null} onClick={saveManual}>
            {busy === "manual" ? "Saving…" : `Save ${fmtMonthLong(month)}`}
          </button>
        </div>
        {err && (
          <p className="form-error" role="alert">
            {err}
          </p>
        )}
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>Monthly prices</h2>
          <span className="label">Fuel Prices tab</span>
        </div>
        <ul className="history">
          {shown.map((p) => (
            <li key={p.month} className="history__item">
              <div className="history__row">
                <div className="history__main">
                  <div className="mono">{fmtMonthLong(p.month)}</div>
                  <div className="small">
                    <span className={`source source--${(p.source ?? "none").toLowerCase()}`}>{p.source === "Manual" ? "Manual · locked" : (p.source ?? "Not set yet")}</span>
                  </div>
                </div>
                <span className="mono price__value price__value--small">{p.price?.toFixed(2) ?? "—"}</span>
                {p.source === "Manual" ? (
                  <button type="button" className="btn btn--ghost btn--small" disabled={!data.canWrite || busy !== null} onClick={() => unlock(p.month)}>
                    {busy === `unlock-${p.month}` ? "…" : "Unlock"}
                  </button>
                ) : (
                  <button type="button" className="icon-btn" aria-label={`Set the ${fmtMonthLong(p.month)} price`} disabled={!data.canWrite} onClick={() => { setMonth(p.month); scrollTo({ top: 0, behavior: reduceMotion() ? "auto" : "smooth" }); }}>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden="true">
                      <path d="M4 20v-4L15 5l4 4L8 20Z" />
                    </svg>
                  </button>
                )}
              </div>
            </li>
          ))}
        </ul>
        <p className="muted small">Unlocking keeps the price but lets the monthly WOQOD check replace it.</p>
      </section>
    </>
  );
}
