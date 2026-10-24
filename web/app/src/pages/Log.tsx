import { useEffect, useRef, useState } from "react";
import type { DataResponse, Entry, WriteResponse } from "../../../shared/types";
import { deleteConsequence, type EntryInput } from "../../../shared/writes";
import { api, useData, useWoqod, type WriteError } from "../data";
import { fmt, fmtDate, fmtMonthLong, qar } from "../format";
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
  const { data, error, setData, setSheet, loading } = useData();
  const woqod = useWoqod();
  const [tab, setTab] = useState<Tab>("new");
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
      <div className="page-head">
        <h1 className="page-title">Log</h1>
        <div className="seg" role="tablist" aria-label="Log sections">
          {(
            [
              ["new", editing ? "EDIT" : "NEW FILL-UP"],
              ["history", "HISTORY"],
              ["prices", "PRICES"],
            ] as [Tab, string][]
          ).map(([id, label]) => (
            <button key={id} type="button" role="tab" className="seg__btn" aria-selected={tab === id} aria-pressed={tab === id} onClick={() => setTab(id)}>
              {label}
            </button>
          ))}
        </div>
      </div>

      <SheetBanner data={data} loading={loading} onSwitch={setSheet} />

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

      {tab === "prices" && <Prices data={data} />}

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

function Prices({ data }: { data: DataResponse }) {
  const list = data.prices.filter((p) => p.price !== null).slice(-12).reverse();
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>Monthly prices</h2>
        <span className="label">{data.settings.fuelGrade} · Fuel Prices tab</span>
      </div>
      <p className="muted small">Typing in a month's price by hand, and saving WOQOD prices automatically, arrive in phase 6.</p>
      <ul className="history">
        {list.map((p) => (
          <li key={p.month} className="history__item">
            <div className="history__row">
              <div className="history__main">
                <div className="mono">{fmtMonthLong(p.month)}</div>
                <div className="muted small">{p.source ?? "—"}</div>
              </div>
              <span className="mono price__value price__value--small">{p.price!.toFixed(2)}</span>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}
