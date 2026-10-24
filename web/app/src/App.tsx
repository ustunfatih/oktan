import { useEffect, useState } from "react";
import type { SummaryResponse } from "../../shared/types";
import { fmt, fmtDate, qar } from "./format";

type State =
  | { status: "loading" }
  | { status: "error"; message: string; detail?: string }
  | { status: "ready"; data: SummaryResponse };

const firstName = (email: string) => (email.startsWith("ustunfa@") ? "Fatih" : email.split("@")[0]);

export function App() {
  const [state, setState] = useState<State>({ status: "loading" });

  useEffect(() => {
    fetch("/api/summary")
      .then(async (res) => {
        const body = await res.json();
        if (!res.ok) setState({ status: "error", message: body.error ?? `Error ${res.status}`, detail: body.detail });
        else setState({ status: "ready", data: body as SummaryResponse });
      })
      .catch((e: unknown) => setState({ status: "error", message: "Could not reach the server", detail: String(e) }));
  }, []);

  return (
    <div className="shell">
      <header className="bar">
        <span className="logo">
          <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 2C12 2 5 10 5 14.5a7 7 0 0 0 14 0C19 10 12 2 12 2Z" fill="none" stroke="currentColor" strokeWidth="2" />
          </svg>
          OKTAN
        </span>
        {state.status === "ready" && <span className="chip">{state.data.sheet === "live" ? "LIVE SHEET" : "DEV SHEET"}</span>}
      </header>

      <main className="content">
        {state.status === "loading" && <p className="muted">Reading your sheet…</p>}

        {state.status === "error" && (
          <section className="card error" role="alert">
            <h1>{state.message}</h1>
            {state.detail && <p className="muted mono">{state.detail}</p>}
          </section>
        )}

        {state.status === "ready" && <Ready data={state.data} />}
      </main>
    </div>
  );
}

function Ready({ data }: { data: SummaryResponse }) {
  const { summary: s, latest, lastClosed } = data;
  return (
    <>
      <h1 className="hello">Hello, {firstName(data.email)}</h1>
      <p className="muted">
        {s.fillUps} fill-ups · {fmt(s.distanceKm)} km logged
      </p>

      <section className="hero card">
        <span className="label">Lifetime consumption</span>
        <span className="big mono">{fmt(s.litersPer100Km, 2)}</span>
        <span className="label">L / 100 km</span>
      </section>

      <section className="grid">
        <Stat label="Cost per km" value={qar(s.costPerKm, 3)} />
        <Stat label="Total spend" value={qar(s.totalSpend)} />
        <Stat label="Fuel bought" value={`${fmt(s.totalLiters, 1)} L`} />
        <Stat label="Km per tank" value={`${fmt(s.avgKmPerTank)} km`} />
      </section>

      {latest && (
        <section className="card">
          <span className="label">Latest fill-up</span>
          <h2>
            {fmtDate(latest.date)} · {latest.station ?? "Unknown station"}
          </h2>
          <p className="mono">
            {fmt(latest.liters, 2)} L · {qar(latest.totalCost)} · {fmt(latest.pricePerLiter, 2)}/L ·{" "}
            {latest.mode ?? "—"}
          </p>
          <p className="muted">
            {latest.distanceKm == null ? `Trip in progress since ${fmt(latest.odometer)} km` : `${fmt(latest.distanceKm)} km`}
          </p>
        </section>
      )}

      {lastClosed && lastClosed.id !== latest?.id && (
        <section className="card">
          <span className="label">Last completed trip</span>
          <h2>
            {fmtDate(lastClosed.date)} · {fmt(lastClosed.distanceKm)} km
          </h2>
          <p className="mono">
            {fmt(lastClosed.litersPer100Km, 2)} L/100 km · {qar(lastClosed.costPerKm, 3)}/km
          </p>
        </section>
      )}

      <p className="muted small">
        Signed in as {data.email}. Phase 2 preview: dashboard, analytics and logging come next.
      </p>
    </>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="card stat">
      <span className="label">{label}</span>
      <span className="mono value">{value}</span>
    </div>
  );
}
