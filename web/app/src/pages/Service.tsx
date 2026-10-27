import { useEffect, useState, type FormEvent } from "react";
import { addMonths, jobTotals, validateJob, type JobFieldErrors, type JobInput, type PlanItem, type ServiceJob } from "../../../shared/maintenance";
import type { DataResponse, WriteResponse } from "../../../shared/types";
import { api, useData, type WriteError } from "../data";
import { fmt, fmtDate, qar, qatarToday } from "../format";

type Tab = "new" | "history" | "plan";
const TABS: [Tab, string][] = [
  ["new", "NEW SERVICE"],
  ["history", "HISTORY"],
  ["plan", "PLAN"],
];

/** The Service tab: log a job, look back at history, and set the intervals. */
export function Service() {
  const { data, setData } = useData();
  const [tab, setTab] = useState<Tab>("new");
  const [editing, setEditing] = useState<ServiceJob | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    if (!notice) return;
    const id = setTimeout(() => setNotice(null), 6000);
    return () => clearTimeout(id);
  }, [notice]);

  if (!data) return <p className="muted page-loading" role="status">Reading your sheet…</p>;

  const done = (next: DataResponse, message: string) => {
    setData(next);
    setNotice(message);
  };

  return (
    <div className="dashboard service">
      <div className="page-head">
        <h1 className="page-title">Service</h1>
        <div className="seg" role="group" aria-label="Service sections">
          {TABS.map(([id, label]) => (
            <button
              key={id}
              type="button"
              className="seg__btn"
              aria-pressed={tab === id}
              onClick={() => {
                setTab(id);
                if (id !== "new") setEditing(null);
              }}
            >
              {id === "new" && editing ? "EDIT JOB" : label}
            </button>
          ))}
        </div>
      </div>

      {tab === "new" && (
        <JobForm
          data={data}
          editing={editing}
          onDone={(next, message) => {
            setEditing(null);
            done(next, message);
          }}
          onConflict={setData}
          onCancel={() => {
            setEditing(null);
            setTab("history");
          }}
        />
      )}
      {tab === "history" && (
        <History
          data={data}
          onEdit={(job) => {
            setEditing(job);
            setTab("new");
            scrollTo({ top: 0 });
          }}
          onDone={done}
          onConflict={setData}
        />
      )}
      {tab === "plan" && <PlanEditor data={data} onDone={done} onConflict={setData} />}

      {notice && (
        <div className="toast" role="status">
          <span>{notice}</span>
        </div>
      )}
    </div>
  );
}

// ── New job ────────────────────────────────────────────────────────────────

const num = (s: string) => (s.trim() === "" ? null : Number(s.replace(",", ".")));

type Draft = Record<"date" | "odometer" | "cost" | "description" | "workshop" | "nextKm" | "nextDate" | "notes" | "category", string>;

const blankDraft = (data: DataResponse): Draft => ({
  date: qatarToday(),
  odometer: data.service.highestOdometer?.toString() ?? "",
  category: data.service.plan.find((p) => p.category === "Oil and filter")?.category ?? data.service.plan[0]?.category ?? "",
  cost: "",
  description: "",
  workshop: "",
  nextKm: "",
  nextDate: "",
  notes: "",
});

function JobForm({
  data,
  editing,
  onDone,
  onConflict,
  onCancel,
}: {
  data: DataResponse;
  editing: ServiceJob | null;
  onDone: (next: DataResponse, message: string) => void;
  onConflict: (next: DataResponse) => void;
  onCancel: () => void;
}) {
  const s = data.service;
  const [draft, setDraft] = useState<Draft>(() =>
    editing
      ? {
          date: editing.date,
          odometer: String(editing.odometer),
          category: editing.category,
          cost: editing.costQar?.toString() ?? "",
          description: editing.description,
          workshop: editing.workshop,
          nextKm: editing.nextDueKm?.toString() ?? "",
          nextDate: editing.nextDueDate ?? "",
          notes: editing.notes,
        }
      : blankDraft(data),
  );
  const [tried, setTried] = useState(false);
  const [busy, setBusy] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [serverErrors, setServerErrors] = useState<JobFieldErrors>({});
  const set = (patch: Partial<Draft>) => setDraft((d) => ({ ...d, ...patch }));

  const input = (d: Draft): Partial<JobInput> => ({
    date: d.date,
    odometer: num(d.odometer) ?? Number.NaN,
    category: d.category,
    description: d.description.trim(),
    costQar: num(d.cost),
    workshop: d.workshop.trim(),
    nextDueKm: num(d.nextKm),
    nextDueDate: d.nextDate || null,
    notes: d.notes.trim(),
  });
  const ctx = { today: qatarToday(), highestOdometer: s.highestOdometer, categories: s.plan.map((p) => p.category) };
  const errors: JobFieldErrors = { ...validateJob(input(draft), ctx), ...serverErrors };
  const show = (k: keyof JobInput) => (tried || serverErrors[k]) && errors[k];
  const field = (k: keyof JobInput) => ({ "aria-invalid": !!show(k), "aria-describedby": show(k) ? `job-${k}-err` : undefined });
  const msg = (k: keyof JobInput) => show(k) && <span className="field__err" id={`job-${k}-err`}>{show(k)}</span>;

  const planItem = s.plan.find((p) => p.category === draft.category);
  const odo = num(draft.odometer);
  const suggestKm = planItem?.everyKm != null && odo != null ? odo + planItem.everyKm : null;
  const suggestDate = planItem?.everyMonths != null && draft.date ? addMonths(draft.date, planItem.everyMonths) : null;
  const workshops = [...new Set(s.jobs.map((j) => j.workshop).filter(Boolean))].slice(0, 6);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setFormError(null);
    setServerErrors({});
    const clean = input(draft);
    if (Object.keys(validateJob(clean, ctx)).length) {
      setTried(true);
      return;
    }
    const job: JobInput = {
      date: clean.date!,
      odometer: clean.odometer!,
      category: clean.category!,
      description: clean.description ?? "",
      costQar: clean.costQar ?? null,
      workshop: clean.workshop ?? "",
      nextDueKm: clean.nextDueKm ?? null,
      nextDueDate: clean.nextDueDate ?? null,
      notes: clean.notes ?? "",
    };
    setBusy(true);
    try {
      const res = editing
        ? await api<WriteResponse>(`/api/service/${editing.id}`, { method: "PUT", body: { job, rowSeen: editing.row } })
        : await api<WriteResponse>("/api/service", { method: "POST", body: { job, rowCountSeen: s.rowCount } });
      if (!editing) setDraft(blankDraft(res.data));
      onDone(res.data, editing ? "Job updated. The sheet's Maintenance tab has the change." : `Saved ${job.category.toLowerCase()} on ${fmtDate(job.date)}.`);
    } catch (err) {
      const w = err as WriteError;
      setFormError(w.message);
      if (w.fields) setServerErrors(w.fields as JobFieldErrors);
      if (w.data) onConflict(w.data);
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{editing ? `Edit the ${fmtDate(editing.date)} job` : "Log a service"}</h2>
        <span className="label">Saved to your sheet</span>
      </div>
      <form className="entry-form" onSubmit={submit} noValidate>
        <div className="form-grid service-grid">
          <label className="field">
            <span className="field__label">Date</span>
            <input type="date" max={qatarToday()} value={draft.date} onChange={(e) => set({ date: e.target.value })} {...field("date")} />
            {msg("date")}
          </label>
          <label className="field">
            <span className="field__label">Odometer · km</span>
            <input type="text" inputMode="numeric" value={draft.odometer} onChange={(e) => set({ odometer: e.target.value })} {...field("odometer")} />
            {msg("odometer")}
          </label>
          <label className="field">
            <span className="field__label">Category</span>
            <select className="field__select" value={draft.category} onChange={(e) => set({ category: e.target.value })} {...field("category")}>
              {!planItem && draft.category && <option value={draft.category}>{draft.category} (not in plan)</option>}
              {s.plan.map((p) => (
                <option key={p.category} value={p.category}>
                  {p.category}
                </option>
              ))}
            </select>
            {msg("category")}
          </label>
          <label className="field">
            <span className="field__label">Cost · QAR (optional)</span>
            <input type="text" inputMode="decimal" value={draft.cost} onChange={(e) => set({ cost: e.target.value })} {...field("costQar")} />
            {msg("costQar")}
          </label>
          <label className="field form-grid__wide">
            <span className="field__label">What was done (optional)</span>
            <input type="text" maxLength={200} placeholder="e.g. Two front tyres" value={draft.description} onChange={(e) => set({ description: e.target.value })} {...field("description")} />
            {msg("description")}
          </label>
          <label className="field">
            <span className="field__label">Workshop (optional)</span>
            <input type="text" maxLength={60} value={draft.workshop} onChange={(e) => set({ workshop: e.target.value })} {...field("workshop")} />
            {msg("workshop")}
          </label>
          {workshops.length > 0 && (
            <div className="field form-grid__wide">
              <span className="field__label">Recent workshops</span>
              <div className="chips" role="group" aria-label="Recent workshops">
                {workshops.map((w) => (
                  <button key={w} type="button" className="chip-btn" aria-pressed={draft.workshop === w} onClick={() => set({ workshop: w })}>
                    {w}
                  </button>
                ))}
              </div>
            </div>
          )}
          <fieldset className="field form-grid__wide">
            <legend className="field__label">Next due (optional)</legend>
            {planItem && (suggestKm !== null || suggestDate !== null) && (
              <p className="muted small">
                Your plan for {planItem.category.toLowerCase()}:{" "}
                {[suggestKm !== null && `${fmt(suggestKm)} km`, suggestDate !== null && fmtDate(suggestDate)].filter(Boolean).join(" or ")}.{" "}
                <button
                  type="button"
                  className="link-btn"
                  onClick={() => set({ nextKm: suggestKm !== null ? String(suggestKm) : draft.nextKm, nextDate: suggestDate ?? draft.nextDate })}
                >
                  Use these
                </button>
              </p>
            )}
            <div className="form-grid service-grid">
              <label className="field">
                <span className="field__label">Due at · km</span>
                <input type="text" inputMode="numeric" value={draft.nextKm} onChange={(e) => set({ nextKm: e.target.value })} {...field("nextDueKm")} />
                {msg("nextDueKm")}
              </label>
              <label className="field">
                <span className="field__label">Due by · date</span>
                <input type="date" value={draft.nextDate} onChange={(e) => set({ nextDate: e.target.value })} {...field("nextDueDate")} />
                {msg("nextDueDate")}
              </label>
            </div>
          </fieldset>
          <label className="field form-grid__wide">
            <span className="field__label">Notes (optional)</span>
            <textarea rows={2} maxLength={500} value={draft.notes} onChange={(e) => set({ notes: e.target.value })} {...field("notes")} />
            {msg("notes")}
          </label>
        </div>

        {formError && (
          <p className="form-error" role="alert">
            {formError}
          </p>
        )}
        <div className="form-actions form-actions--start">
          <button type="submit" className="btn btn--big" disabled={!data.canWrite || busy}>
            {busy ? "Saving…" : editing ? "Save changes" : "Save service"}
          </button>
          {editing && (
            <button type="button" className="btn btn--ghost" onClick={onCancel}>
              Cancel
            </button>
          )}
        </div>
        {!data.canWrite && <p className="muted small">Saving to the live sheet is locked. Switch on test mode in Settings to try it.</p>}
      </form>
    </section>
  );
}

// ── History ────────────────────────────────────────────────────────────────

function History({
  data,
  onEdit,
  onDone,
  onConflict,
}: {
  data: DataResponse;
  onEdit: (job: ServiceJob) => void;
  onDone: (next: DataResponse, message: string) => void;
  onConflict: (next: DataResponse) => void;
}) {
  const s = data.service;
  const [confirming, setConfirming] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const list = [...s.jobs].sort((a, b) => b.date.localeCompare(a.date) || b.odometer - a.odometer);
  const totals = jobTotals(s.jobs);

  const remove = async (job: ServiceJob) => {
    setBusy(true);
    setErr(null);
    try {
      const res = await api<WriteResponse>(`/api/service/${job.id}`, { method: "DELETE", body: { rowSeen: job.row } });
      setConfirming(null);
      onDone(res.data, `Deleted the ${fmtDate(job.date)} job. It's recorded in the sheet's App_Log tab.`);
    } catch (e) {
      const w = e as WriteError;
      setErr(w.message);
      if (w.data) onConflict(w.data);
    } finally {
      setBusy(false);
    }
  };

  if (!s.hasJobsTab) {
    return (
      <section className="panel">
        <p className="muted">No service recorded yet. Log your first one on the New service tab.</p>
      </section>
    );
  }

  return (
    <section className="panel">
      <div className="strip" aria-label="Service totals">
        <div className="figure">
          <span className="label">Jobs</span>
          <span className="figure__value">{fmt(totals.jobs)}</span>
        </div>
        <div className="figure">
          <span className="label">Spent</span>
          <span className="figure__value">{qar(totals.spendQar, 0)}</span>
        </div>
        <div className="figure">
          <span className="label">Per 1,000 km</span>
          <span className="figure__value">{totals.perThousandKm === null ? "—" : qar(totals.perThousandKm, 0)}</span>
        </div>
      </div>
      {s.skipped > 0 && (
        <p className="muted small">
          {s.skipped} row{s.skipped === 1 ? "" : "s"} can't be read and aren't shown. Fix them in the Maintenance tab.
        </p>
      )}
      {err && (
        <p className="form-error" role="alert">
          {err}
        </p>
      )}
      <ul className="history">
        {list.map((j) => (
          <li key={j.id} className="history__item">
            <div className="history__row">
              <div className="history__main">
                <div className="mono">
                  {fmtDate(j.date)} · {j.category}
                </div>
                <div className="muted small">
                  {fmt(j.odometer)} km · {j.costQar === null ? "no cost" : qar(j.costQar, 0)}
                  {j.workshop ? ` · ${j.workshop}` : ""}
                </div>
                {j.description && <div className="small">{j.description}</div>}
                {j.nextDueKm !== null || j.nextDueDate ? (
                  <div className="muted small">
                    Next due {[j.nextDueKm !== null && `${fmt(j.nextDueKm)} km`, j.nextDueDate && fmtDate(j.nextDueDate)].filter(Boolean).join(" or ")}
                  </div>
                ) : null}
              </div>
              <button type="button" className="icon-btn" aria-label={`Edit the ${fmtDate(j.date)} ${j.category.toLowerCase()} job`} disabled={!data.canWrite} onClick={() => onEdit(j)}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden="true">
                  <path d="M4 20v-4L15 5l4 4L8 20Z" />
                </svg>
              </button>
              <button
                type="button"
                className="icon-btn icon-btn--danger"
                aria-label={`Delete the ${fmtDate(j.date)} ${j.category.toLowerCase()} job`}
                disabled={!data.canWrite}
                onClick={() => setConfirming(confirming === j.id ? null : j.id)}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden="true">
                  <path d="M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13" />
                </svg>
              </button>
            </div>
            {confirming === j.id && (
              <div className="confirm" role="alertdialog" aria-label="Confirm delete">
                <p>Delete the {fmtDate(j.date)} {j.category.toLowerCase()} job? It's removed from the sheet and kept in App_Log.</p>
                <div className="confirm__actions">
                  <button type="button" className="btn btn--ghost btn--small" onClick={() => setConfirming(null)}>
                    Cancel
                  </button>
                  <button type="button" className="btn btn--danger btn--small" disabled={busy} onClick={() => remove(j)}>
                    {busy ? "Deleting…" : "Delete"}
                  </button>
                </div>
              </div>
            )}
          </li>
        ))}
      </ul>
      {totals.byCategory.length > 0 && (
        <p className="muted small">
          Most spent on: {totals.byCategory.slice(0, 3).map((c) => `${c.category} ${qar(c.spendQar, 0)}`).join(", ")}.
        </p>
      )}
    </section>
  );
}

// ── Plan ───────────────────────────────────────────────────────────────────

type Row = { category: string; everyKm: string; everyMonths: string };
const toRow = (p: PlanItem): Row => ({ category: p.category, everyKm: p.everyKm?.toString() ?? "", everyMonths: p.everyMonths?.toString() ?? "" });

function PlanEditor({
  data,
  onDone,
  onConflict,
}: {
  data: DataResponse;
  onDone: (next: DataResponse, message: string) => void;
  onConflict: (next: DataResponse) => void;
}) {
  const s = data.service;
  const [rows, setRows] = useState<Row[]>(() => s.plan.map(toRow));
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const update = (i: number, patch: Partial<Row>) => setRows((r) => r.map((row, j) => (j === i ? { ...row, ...patch } : row)));
  const usedBy = (category: string) => s.jobs.filter((j) => j.category === category).length;

  const save = async () => {
    setErr(null);
    const plan: PlanItem[] = rows.map((r) => ({ category: r.category.trim(), everyKm: num(r.everyKm), everyMonths: num(r.everyMonths) }));
    if (plan.some((p) => p.everyKm !== null && Number.isNaN(p.everyKm)) || plan.some((p) => p.everyMonths !== null && Number.isNaN(p.everyMonths))) {
      setErr("Intervals must be numbers, or left blank.");
      return;
    }
    setBusy(true);
    try {
      const res = await api<{ data: DataResponse; message: string }>("/api/service-plan", { method: "PUT", body: { plan } });
      setRows(res.data.service.plan.map(toRow));
      onDone(res.data, "Service plan saved.");
    } catch (e) {
      const w = e as WriteError;
      setErr(w.message);
      if (w.data) onConflict(w.data);
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="panel">
      <div className="panel-head">
        <h2>Service plan</h2>
        <span className="label">Km and months between services</span>
      </div>
      {s.planIsDefault && (
        <p className="banner banner--test" role="status">
          These are starting values. Check them against your service book, then save to keep them in your sheet.
        </p>
      )}
      <p className="muted small">A category counts toward the next due date only if it has an interval. Leave a box blank to skip that measure.</p>
      <div className="plan-rows">
        {rows.map((r, i) => {
          const used = usedBy(r.category);
          return (
            <div key={i} className="plan-row">
              <label className="field">
                <span className="field__label">Category</span>
                <input type="text" maxLength={40} value={r.category} onChange={(e) => update(i, { category: e.target.value })} />
              </label>
              <label className="field">
                <span className="field__label">Every · km</span>
                <input type="text" inputMode="numeric" placeholder="none" value={r.everyKm} onChange={(e) => update(i, { everyKm: e.target.value })} />
              </label>
              <label className="field">
                <span className="field__label">Every · months</span>
                <input type="text" inputMode="numeric" placeholder="none" value={r.everyMonths} onChange={(e) => update(i, { everyMonths: e.target.value })} />
              </label>
              <button
                type="button"
                className="icon-btn icon-btn--danger"
                aria-label={`Remove ${r.category || "this category"}`}
                onClick={() => setRows((rs) => rs.filter((_, j) => j !== i))}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden="true">
                  <path d="M6 6l12 12M18 6L6 18" />
                </svg>
              </button>
              {used > 0 && <p className="muted small plan-row__note">{used} job{used === 1 ? "" : "s"} use this category. They stay in history, but stop counting toward a due date.</p>}
            </div>
          );
        })}
      </div>
      <div className="form-actions form-actions--start">
        <button type="button" className="btn btn--ghost" onClick={() => setRows((rs) => [...rs, { category: "", everyKm: "", everyMonths: "" }])}>
          Add category
        </button>
        <button type="button" className="btn" disabled={!data.canWrite || busy} onClick={save}>
          {busy ? "Saving…" : "Save plan"}
        </button>
      </div>
      {err && (
        <p className="form-error" role="alert">
          {err}
        </p>
      )}
    </section>
  );
}


