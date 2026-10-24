import { useMemo } from "react";
import { buildDashboard, type DashboardModel } from "../../../shared/dashboard";
import type { DataResponse, Settings, WoqodResponse } from "../../../shared/types";
import { Gauge } from "../charts/Gauge";
import { MonthlyBars } from "../charts/MonthlyBars";
import { TrendChart } from "../charts/TrendChart";
import { useData, useWoqod, type LoadError } from "../data";
import { fmt, fmtDate, fmtDayMonth, fmtMonthLong, qar, qatarToday } from "../format";
import { Link } from "../router";

export function Dashboard() {
  const { data, error, loading } = useData();
  const woqod = useWoqod();
  const today = qatarToday();
  const model = useMemo(
    () => (data ? buildDashboard(data.entries, data.prices, data.settings, today) : null),
    [data, today],
  );

  if (!data || !model) {
    if (error) return <ErrorPanel error={error} />;
    return <Skeleton />;
  }

  return (
    <div className="dashboard">
      {error && <ErrorBanner error={error} />}
      <div className="page-head">
        <h1 className="page-title">Vehicle telemetry</h1>
        <span className="page-sub mono">
          {data.entries[0] && `${fmtDate(data.entries[0].date).toUpperCase()} → ${fmtDate(data.entries.at(-1)!.date).toUpperCase()}`} ·{" "}
          {model.summary.fillUps} FILL-UPS · {data.settings.fuelGrade.toUpperCase()}
          {loading && " · UPDATING…"}
        </span>
      </div>

      <section className="row row--hero">
        <EfficiencyCard model={model} />
        <div className="kpis">
          <Kpi label="Cost per km" value={fmt(model.summary.costPerKm, 3)} unit="QAR" note={`QAR ${fmt((model.summary.costPerKm ?? 0) * 100, 2)} per 100 km`} />
          <Kpi label={`Spent · ${today.slice(0, 4)}`} value={fmt(model.year.spend, 2)} unit="QAR" note={`${fmtMonthLong(today).split(" ")[0]}: ${qar(model.month.spend)} · ${model.month.fills} fill${model.month.fills === 1 ? "" : "s"}`} />
          <Kpi label="Distance logged" value={fmt(model.summary.distanceKm)} unit="km" note={`${model.summary.closedTrips} completed trips`} />
          <Kpi label="Range per tank" value={fmt(model.summary.avgKmPerTank)} unit="km" note={`Full ${fmt(data.settings.tankCapacityL)} L tank ≈ ${fmt(model.fullTankRangeKm)} km`} />
          <Kpi label="Fuel bought" value={fmt(model.summary.totalLiters, 1)} unit="L" note={`Avg fill ${fmt(model.summary.totalLiters / Math.max(1, model.summary.fillUps), 1)} L · ${qar(model.summary.totalSpend / Math.max(1, model.summary.fillUps))}`} />
          <Kpi
            label="Next fill-up"
            value={model.nextFill ? `~${fmtDayMonth(model.nextFill.date)}` : "—"}
            accent
            note={model.nextFill ? `Every ${model.nextFill.everyDays} days on average` : "Needs two fill-ups"}
          />
        </div>
      </section>

      <section className="row">
        <div className="panel panel--wide">
          <div className="panel-head">
            <h2>L/100 km per tank</h2>
          </div>
          <TrendChart points={model.trend} average={model.summary.litersPer100Km} best={model.best} worst={model.worst} />
        </div>
        <PricesCard model={model} settings={data.settings} woqod={woqod} />
      </section>

      <section className="row">
        <div className="panel">
          <div className="panel-head">
            <h2>Monthly spend · QAR</h2>
          </div>
          <MonthlyBars months={model.monthly} currentMonth={today.slice(0, 7)} />
        </div>
        <RecentCard model={model} data={data} />
      </section>
    </div>
  );
}

function EfficiencyCard({ model }: { model: DashboardModel }) {
  const { summary: s, lastClosed } = model;
  const better = lastClosed?.litersPer100Km != null && s.litersPer100Km != null && lastClosed.litersPer100Km <= s.litersPer100Km;
  return (
    <div className="panel efficiency">
      <div className="panel-head panel-head--split">
        <span className="label">Efficiency</span>
        <span className="label">Lifetime</span>
      </div>
      <Gauge value={s.litersPer100Km} />
      <div className="efficiency__value mono">{fmt(s.litersPer100Km, 2)}</div>
      <div className="label">L / 100 km · {fmt(model.kmPerLiter, 1)} km/L</div>
      <div className="badges">
        {lastClosed && (
          <span className={`badge ${better ? "badge--good" : "badge--bad"}`}>
            LAST TRIP {fmt(lastClosed.litersPer100Km, 2)} {better ? "▼" : "▲"}
          </span>
        )}
        {model.last5LitersPer100Km !== null && <span className="badge badge--accent">LAST 5 · {fmt(model.last5LitersPer100Km, 2)}</span>}
      </div>
    </div>
  );
}

function Kpi({ label, value, unit, note, accent }: { label: string; value: string; unit?: string; note: string; accent?: boolean }) {
  return (
    <div className="panel kpi">
      <span className="label">{label}</span>
      <span className={`kpi__value mono${accent ? " kpi__value--accent" : ""}`}>
        {value} {unit && <span className="kpi__unit">{unit}</span>}
      </span>
      <span className="kpi__note">{note}</span>
    </div>
  );
}

const GRADE_MATCH: Record<string, RegExp> = { "super 95": /95/, "premium 91": /91/, diesel: /diesel/i };
const SHORT_GRADE = (g: string) => g.replace(/^Gasoline\s+/i, "").replace(/\s*\((\d+)\)/, " $1");

function PricesCard({ model, settings, woqod }: { model: DashboardModel; settings: Settings; woqod: WoqodResponse | null }) {
  const mine = GRADE_MATCH[settings.fuelGrade.toLowerCase()] ?? /95/;
  const sheetPrice = model.currentPrice;
  const prev = model.previousPrice;

  if (woqod?.ok) {
    const sorted = [...woqod.prices].sort((a, b) => Number(mine.test(b.grade)) - Number(mine.test(a.grade)));
    const month = woqod.prices[0]!.month;
    const minePrice = woqod.prices.find((p) => mine.test(p.grade));
    const missingInSheet = !sheetPrice || (minePrice && Math.abs((sheetPrice.price ?? 0) - minePrice.price) > 0.001);
    return (
      <div className="panel prices">
        <div className="panel-head">
          <h2>Pump prices</h2>
          <span className="label">WOQOD · {fmtMonthLong(month).toUpperCase()}</span>
        </div>
        {sorted.map((p, i) =>
          i === 0 && mine.test(p.grade) ? (
            <div key={p.grade} className="price price--mine">
              <div>
                <div className="price__grade">{SHORT_GRADE(p.grade)}</div>
                <div className="price__note">Your grade</div>
              </div>
              <div className="price__value mono">{p.price.toFixed(2)}</div>
            </div>
          ) : (
            <div key={p.grade} className="price">
              <div className="price__grade">{SHORT_GRADE(p.grade)}</div>
              <div className="price__value price__value--small mono">{p.price.toFixed(2)}</div>
            </div>
          ),
        )}
        <p className="prices__foot">
          QAR per litre.{" "}
          {prev?.price != null && minePrice
            ? minePrice.price === prev.price
              ? "Same as last month."
              : `${minePrice.price > prev.price ? "Up" : "Down"} ${fmt(Math.abs(minePrice.price - prev.price), 2)} from last month.`
            : ""}{" "}
          {missingInSheet
            ? "Not in your sheet's Fuel Prices tab yet; automatic saving comes in phase 6."
            : "Matches your sheet's Fuel Prices tab."}
        </p>
      </div>
    );
  }

  return (
    <div className="panel prices">
      <div className="panel-head">
        <h2>Pump price</h2>
        <span className="label">YOUR SHEET</span>
      </div>
      <div className="price price--mine">
        <div>
          <div className="price__grade">{settings.fuelGrade}</div>
          <div className="price__note">{sheetPrice ? `${fmtMonthLong(sheetPrice.month)} · ${sheetPrice.source ?? "sheet"}` : "No price for this month yet"}</div>
        </div>
        <div className="price__value mono">{sheetPrice?.price?.toFixed(2) ?? "—"}</div>
      </div>
      <p className="prices__foot">{woqod ? `WOQOD unavailable right now: ${woqod.error}` : "Checking WOQOD…"}</p>
    </div>
  );
}

function RecentCard({ model, data }: { model: DashboardModel; data: DataResponse }) {
  const avg = model.summary.litersPer100Km;
  const tone = (v: number | null) => (v == null || avg == null ? "" : v <= avg ? "good" : "bad");
  return (
    <div className="panel">
      <div className="panel-head">
        <h2>Recent fill-ups</h2>
        <Link to="/analytics" className="link">
          ALL TRIPS →
        </Link>
      </div>
      <table className="table recent-table">
        <thead>
          <tr>
            <th scope="col">Date</th>
            <th scope="col">Station</th>
            <th scope="col" className="num">L</th>
            <th scope="col" className="num">QAR</th>
            <th scope="col" className="num">km</th>
            <th scope="col" className="num">L/100</th>
          </tr>
        </thead>
        <tbody>
          {model.recent.map((e) => (
            <tr key={e.id}>
              <td>{fmtDayMonth(e.date)}</td>
              <td>{e.station ?? "—"}</td>
              <td className="num">{fmt(e.liters, 2)}</td>
              <td className="num">{fmt(e.totalCost, 2)}</td>
              <td className="num">{e.distanceKm == null ? <span className="accent2">open</span> : fmt(e.distanceKm)}</td>
              <td className={`num ${tone(e.litersPer100Km)}`}>{fmt(e.litersPer100Km, 2)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <ul className="recent-list">
        {model.recent.map((e) => (
          <li key={e.id}>
            <div>
              <div className="mono">
                {fmtDayMonth(e.date)} · {e.station ?? "—"}
              </div>
              <div className="muted small">
                {e.distanceKm == null ? `${fmt(e.liters, 2)} L · ${qar(e.totalCost)}` : `${fmt(e.distanceKm)} km · ${qar(e.totalCost)}`}
              </div>
            </div>
            <span className={`mono ${e.distanceKm == null ? "accent2" : tone(e.litersPer100Km)}`}>
              {e.distanceKm == null ? "OPEN" : fmt(e.litersPer100Km, 2)}
            </span>
          </li>
        ))}
      </ul>
      {data.sheet === "dev" && <p className="muted small">Showing the Oktan DEV sheet.</p>}
    </div>
  );
}

function Skeleton() {
  return (
    <div className="dashboard" aria-busy="true">
      <p className="muted">Reading your sheet…</p>
      <div className="row row--hero">
        <div className="panel skeleton" style={{ height: 320 }} />
        <div className="kpis">
          {Array.from({ length: 6 }, (_, i) => (
            <div key={i} className="panel skeleton" style={{ height: 110 }} />
          ))}
        </div>
      </div>
    </div>
  );
}

function ErrorPanel({ error }: { error: LoadError }) {
  return (
    <section className="panel error-panel" role="alert">
      <h1 className="page-title">{error.message}</h1>
      {error.detail && <p className="muted mono small">{error.detail}</p>}
      {error.kind === "session" ? (
        <button type="button" className="btn" onClick={() => location.reload()}>
          Sign in again
        </button>
      ) : (
        <button type="button" className="btn" onClick={() => location.reload()}>
          Try again
        </button>
      )}
    </section>
  );
}

function ErrorBanner({ error }: { error: LoadError }) {
  return (
    <div className="banner" role="status">
      <span>
        {error.kind === "session" ? "Sign-in expired, so these numbers may be out of date." : `Couldn't refresh: ${error.message}. Showing the last numbers.`}
      </span>
      <button type="button" className="btn btn--small" onClick={() => location.reload()}>
        {error.kind === "session" ? "Sign in" : "Retry"}
      </button>
    </div>
  );
}
