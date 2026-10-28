import { useMemo, useState, type FormEvent } from "react";
import { priceForDate, woqodForGrade } from "../../../shared/prices";
import type { DataResponse, Entry, WoqodResponse, WriteResponse } from "../../../shared/types";
import { validateEntry, type EntryInput, type FieldErrors } from "../../../shared/writes";
import { api, useData, type WriteError } from "../data";
import { fmt, fmtDate, qar, qatarToday } from "../format";

interface Props {
  data: DataResponse;
  woqod: WoqodResponse | null;
  /** Present when editing an existing fill-up. */
  editing?: Entry;
  onSaved: (res: WriteResponse, previous: Entry | null) => void;
  onConflict: (data: DataResponse) => void;
  onCancel?: () => void;
  /** Called when there is no connection and the fill-up was kept on this phone instead. */
  onQueued?: () => void;
}

type Draft = Record<"date" | "odometer" | "liters" | "price" | "cost" | "station", string> & { full: boolean; mode: string };

const num = (s: string) => (s.trim() === "" ? NaN : Number(s.replace(",", ".")));
const two = (n: number) => (Number.isFinite(n) ? n.toFixed(2) : "");

export function EntryForm({ data, woqod, editing, onSaved, onConflict, onCancel, onQueued }: Props) {
  const { queueEntry } = useData();
  const { entries, settings } = data;
  const index = editing ? entries.findIndex((e) => e.id === editing.id) : entries.length;
  const prev = index > 0 ? entries[index - 1]! : null;
  const next = editing && index < entries.length - 1 ? entries[index + 1]! : null;
  const today = qatarToday();
  const woqodMine = woqod?.ok ? woqodForGrade(woqod.prices, settings.fuelGrade) : null;

  const [draft, setDraft] = useState<Draft>(() =>
    editing
      ? {
          date: editing.date,
          odometer: String(editing.odometer ?? ""),
          liters: two(editing.liters),
          price: two(editing.pricePerLiter ?? NaN),
          cost: two(editing.totalCost ?? NaN),
          station: editing.station ?? "",
          full: editing.full,
          mode: editing.mode ?? settings.defaultMode,
        }
      : { date: today, odometer: "", liters: "", price: "", cost: "", station: entries.at(-1)?.station ?? "", full: true, mode: settings.defaultMode },
  );
  const [enterAmount, setEnterAmount] = useState(false);
  const [priceTouched, setPriceTouched] = useState(!!editing);
  const [otherStation, setOtherStation] = useState(false);
  const [touched, setTouched] = useState<Set<string>>(new Set());
  const [submitted, setSubmitted] = useState(false);
  const [saving, setSaving] = useState(false);
  const [serverError, setServerError] = useState<WriteError | null>(null);

  const suggestion = useMemo(() => priceForDate(draft.date, data.prices, woqodMine), [draft.date, data.prices, woqodMine]);
  const price = priceTouched ? num(draft.price) : (suggestion?.price ?? num(draft.price));
  const liters = enterAmount ? Math.round((num(draft.cost) / price) * 100) / 100 : num(draft.liters);
  const cost = enterAmount ? num(draft.cost) : Math.round(num(draft.liters) * price * 100) / 100;

  const input: EntryInput = {
    date: draft.date,
    odometer: num(draft.odometer),
    liters,
    pricePerLiter: price,
    totalCost: cost,
    full: draft.full,
    mode: draft.mode,
    station: draft.station,
  };
  const errors: FieldErrors = { ...validateEntry(input, { prev, next, today, tankCapacityL: settings.tankCapacityL }), ...serverError?.fields };
  const show = (f: keyof FieldErrors) => (submitted || touched.has(f) ? errors[f] : undefined);
  const set = (patch: Partial<Draft>) => {
    setDraft((d) => ({ ...d, ...patch }));
    setServerError(null);
  };
  const touch = (f: string) => setTouched((t) => new Set(t).add(f));

  // Preview of the trip this fill-up closes, using the same formula as the sheet.
  const preview = useMemo(() => {
    if (editing || !prev || prev.odometer === null || !Number.isFinite(input.odometer) || input.odometer <= prev.odometer) return null;
    const km = input.odometer - prev.odometer;
    if (!draft.full || !Number.isFinite(liters)) return { km, l100: null, cpk: null };
    const used = prev.liters - (settings.tankCapacityL - liters);
    return { km, l100: (used / km) * 100, cpk: (used * (prev.pricePerLiter ?? price)) / km };
  }, [editing, prev, input.odometer, draft.full, liters, price, settings.tankCapacityL]);
  const avg = useMemo(() => {
    const trips = entries.filter((e) => e.distanceKm && e.usedFuelL !== null);
    const km = trips.reduce((s, e) => s + e.distanceKm!, 0);
    return km ? (100 * trips.reduce((s, e) => s + e.usedFuelL!, 0)) / km : null;
  }, [entries]);

  const stations = useMemo(() => {
    const recent = [...entries].reverse().map((e) => e.station).filter((s): s is string => !!s);
    return [...new Set([...settings.stations, ...recent])].slice(0, 8);
  }, [entries, settings.stations]);

  async function submit(ev: FormEvent) {
    ev.preventDefault();
    setSubmitted(true);
    if (Object.keys(validateEntry(input, { prev, next, today, tankCapacityL: settings.tankCapacityL })).length) return;
    if (!data.canWrite) return;
    setSaving(true);
    setServerError(null);
    try {
      const res = editing
        ? await api<WriteResponse>(`/api/entries/${editing.id}`, { method: "PUT", body: { entry: input, rowSeen: editing.row } })
        : await api<WriteResponse>("/api/entries", { method: "POST", body: { entry: input, lastIdSeen: entries.at(-1)?.id ?? null } });
      onSaved(res, editing ?? null);
    } catch (e) {
      const err = e as WriteError;
      if (err.kind === "network" && !editing) {
        // No connection: keep the fill-up on this phone; it goes to the sheet when Oktan is reachable again.
        await queueEntry(input, entries.at(-1)?.id ?? null);
        onQueued?.();
        return;
      }
      setServerError(err);
      if (err.data) onConflict(err.data);
    } finally {
      setSaving(false);
    }
  }

  // Where the suggested price came from, shown under the box until the price is typed over.
  const priceSource = priceTouched ? null : (suggestion?.source ?? null);
  const field = (id: keyof FieldErrors) => ({ "aria-invalid": !!show(id), "aria-describedby": show(id) ? `${id}-err` : undefined });
  const Err = ({ id }: { id: keyof FieldErrors }) => (show(id) ? <span id={`${id}-err`} className="field__err">{show(id)}</span> : null);

  return (
    <form className="entry-form" onSubmit={submit} noValidate>
      <div className="form-grid">
        <label className="field">
          <span className="field__label">Date</span>
          <input type="date" value={draft.date} max={today} onChange={(e) => set({ date: e.target.value })} onBlur={() => touch("date")} {...field("date")} />
          <Err id="date" />
        </label>
        <label className="field">
          <span className="field__label">Odometer · km</span>
          <input
            type="text"
            inputMode="numeric"
            placeholder={prev?.odometer != null ? `> ${fmt(prev.odometer)}` : ""}
            value={draft.odometer}
            onChange={(e) => set({ odometer: e.target.value })}
            onBlur={() => touch("odometer")}
            {...field("odometer")}
          />
          <Err id="odometer" />
        </label>

        {enterAmount ? (
          <label className="field">
            <span className="field__label">Amount paid · QAR</span>
            <input type="text" inputMode="decimal" value={draft.cost} onChange={(e) => set({ cost: e.target.value })} onBlur={() => touch("totalCost")} {...field("totalCost")} />
            <Err id="totalCost" />
          </label>
        ) : (
          <label className="field">
            <span className="field__label">Litres</span>
            <input type="text" inputMode="decimal" value={draft.liters} onChange={(e) => set({ liters: e.target.value })} onBlur={() => touch("liters")} {...field("liters")} />
            <Err id="liters" />
          </label>
        )}

        <label className="field">
          <span className="field__label">Price · QAR/L</span>
          <input
            type="text"
            inputMode="decimal"
            className="input--accent"
            value={priceTouched ? draft.price : two(suggestion?.price ?? NaN)}
            onChange={(e) => {
              setPriceTouched(true);
              set({ price: e.target.value });
            }}
            onBlur={() => touch("pricePerLiter")}
            {...field("pricePerLiter")}
            aria-describedby={[priceSource ? "price-source" : "", show("pricePerLiter") ? "pricePerLiter-err" : ""].filter(Boolean).join(" ") || undefined}
          />
          {priceSource && (
            <span id="price-source" className="field__hint">
              {priceSource.charAt(0).toUpperCase() + priceSource.slice(1)}
            </span>
          )}
          <Err id="pricePerLiter" />
        </label>
      </div>

      <div className="stack-tight">
        <div className="total">
          <div className="total__row">
            <span className="field__label">{enterAmount ? "Litres" : "Total cost"}</span>
            <span className="total__value mono">
              {enterAmount ? `${Number.isFinite(liters) ? fmt(liters, 2) : "—"} L` : Number.isFinite(cost) ? qar(cost) : "QAR —"}
            </span>
          </div>
          <button type="button" className="link-btn" onClick={() => setEnterAmount(!enterAmount)}>
            {enterAmount ? "Enter litres instead" : "Enter the amount paid instead"}
          </button>
        </div>
        {enterAmount && <Err id="liters" />}
        {!enterAmount && <Err id="totalCost" />}
      </div>

      <div className="form-row">
        <fieldset className="field">
          <legend className="field__label">Drive mode</legend>
          <div className="seg seg--wide">
            {settings.modes.map((m) => (
              <button key={m} type="button" className="seg__btn" aria-pressed={draft.mode === m} onClick={() => set({ mode: m })}>
                {m.toUpperCase()}
              </button>
            ))}
          </div>
          <Err id="mode" />
        </fieldset>
        <fieldset className="field">
          <legend className="field__label">Tank</legend>
          <div className="seg seg--wide">
            <button type="button" className="seg__btn" aria-pressed={draft.full} onClick={() => set({ full: true })}>
              FULL
            </button>
            <button type="button" className="seg__btn" aria-pressed={!draft.full} onClick={() => set({ full: false })}>
              PARTIAL
            </button>
          </div>
        </fieldset>
      </div>

      <fieldset className="field">
        <legend className="field__label">Gas station</legend>
        <div className="chips">
          {stations.map((s) => (
            <button
              key={s}
              type="button"
              className="chip-btn"
              aria-pressed={!otherStation && draft.station === s}
              onClick={() => {
                setOtherStation(false);
                set({ station: s });
              }}
            >
              {s}
            </button>
          ))}
          <button type="button" className="chip-btn" aria-pressed={otherStation} onClick={() => setOtherStation(true)}>
            + Other
          </button>
        </div>
        {otherStation && (
          <input type="text" placeholder="Station name" value={draft.station} onChange={(e) => set({ station: e.target.value })} autoFocus aria-label="Station name" {...field("station")} />
        )}
        <Err id="station" />
      </fieldset>

      {preview && (
        <section className="preview" aria-live="polite">
          <div className="field__label">Trip being closed · {prev && fmtDate(prev.date)} → {fmtDate(draft.date)}</div>
          <div className="preview__grid">
            <div>
              <span className="label">Distance</span>
              <span className="mono preview__value">{fmt(preview.km)} km</span>
            </div>
            <div>
              <span className="label">L/100 km</span>
              <span className="mono preview__value accent">{fmt(preview.l100, 2)}</span>
            </div>
            <div>
              <span className="label">QAR/km</span>
              <span className="mono preview__value">{fmt(preview.cpk, 3)}</span>
            </div>
          </div>
          <p className="muted small">
            {preview.l100 === null
              ? "Partial fill: efficiency is worked out at the next full tank."
              : avg !== null
                ? `${preview.l100 <= avg ? "Better" : "Worse"} than your ${fmt(avg, 2)} average by ${fmt(Math.abs(preview.l100 - avg), 2)} L/100 km.`
                : ""}
          </p>
        </section>
      )}

      {serverError && !serverError.fields && (
        <p className="form-error" role="alert">
          {serverError.message}
        </p>
      )}
      {!data.canWrite && <p className="form-error">Saving to your live sheet is locked. Switch to test mode above to try it.</p>}

      <div className="stack-tight">
        <div className="form-actions">
          {onCancel && (
            <button type="button" className="btn btn--ghost" onClick={onCancel}>
              Cancel
            </button>
          )}
          <button type="submit" className="btn btn--big" disabled={saving || !data.canWrite}>
            {saving ? "Saving…" : editing ? "Save changes" : "Save to sheet"}
          </button>
        </div>
        {!editing && prev && (
          <p className="muted small">
            Writes the closing odometer to the {fmtDate(prev.date)} row and adds a new row for this fill-up.
          </p>
        )}
      </div>
    </form>
  );
}
