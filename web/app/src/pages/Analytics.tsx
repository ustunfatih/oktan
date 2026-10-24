import { useMemo, useState } from "react";
import {
  ALL,
  applyFilters,
  avgPricePaid,
  byMode,
  byStation,
  closedTrips,
  cumulativeSpend,
  distribution,
  efficiencyHeat,
  priceHistory,
  rangeStart,
  records,
  seasonEfficiency,
  type Filters,
  type GroupStats,
  type RangeKey,
} from "../../../shared/analytics";
import { summarize } from "../../../shared/metrics";
import type { DataResponse, Entry } from "../../../shared/types";
import { ColumnChart } from "../charts/ColumnChart";
import { SeriesChart } from "../charts/SeriesChart";
import { useData } from "../data";
import { fmt, fmtDate, fmtDayMonth, fmtMonth, fmtMonthLong, qar, qatarToday } from "../format";

const RANGES: { key: RangeKey; label: (year: string) => string }[] = [
  { key: "3m", label: () => "3M" },
  { key: "6m", label: () => "6M" },
  { key: "12m", label: () => "12M" },
  { key: "ytd", label: (y) => y },
  { key: "all", label: () => "ALL" },
];
const MONTH_HEAD = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
const NO_STATION = "Not recorded";

export function Analytics() {
  const { data, error } = useData();
  const [filters, setFilters] = useState<Filters>(ALL);
  const today = qatarToday();

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
  return <AnalyticsView data={data} filters={filters} setFilters={setFilters} today={today} />;
}

function AnalyticsView({ data, filters, setFilters, today }: { data: DataResponse; filters: Filters; setFilters: (f: Filters) => void; today: string }) {
  const m = useMemo(() => {
    const list = applyFilters(data.entries, filters, today);
    const trips = closedTrips(list);
    return {
      list,
      trips,
      summary: summarize(list),
      modes: byMode(list, data.settings.modes),
      stations: byStation(list),
      summer: seasonEfficiency(list, [6, 7, 8]),
      winter: seasonEfficiency(list, [12, 1, 2, 3]),
      heat: efficiencyHeat(list),
      bins: distribution(list),
      cumulative: cumulativeSpend(list),
      prices: priceHistory(data.prices, rangeStart(filters.range, today), today),
      records: records(list, priceHistory(data.prices, rangeStart(filters.range, today), today)),
      avgPaid: avgPricePaid(list),
    };
  }, [data, filters, today]);

  const stationOptions = useMemo(() => {
    const seen = new Set([...data.settings.stations, ...data.entries.map((e) => e.station).filter((s): s is string => !!s)]);
    return [...seen];
  }, [data]);
  const hasUnrecorded = data.entries.some((e) => !e.station);
  const filtered = filters.range !== "all" || filters.mode !== null || filters.station !== null;

  return (
    <div className="dashboard">
      <div className="page-head">
        <h1 className="page-title">Deep analysis</h1>
        <div className="filters" role="group" aria-label="Filters">
          <div className="seg" role="group" aria-label="Period">
            {RANGES.map((r) => (
              <button
                key={r.key}
                type="button"
                className="seg__btn"
                aria-pressed={filters.range === r.key}
                onClick={() => setFilters({ ...filters, range: r.key })}
              >
                {r.label(today.slice(0, 4))}
              </button>
            ))}
          </div>
          <label className="select">
            <span className="sr-only">Drive mode</span>
            <select value={filters.mode ?? ""} onChange={(e) => setFilters({ ...filters, mode: e.target.value || null })}>
              <option value="">MODE: ALL</option>
              {data.settings.modes.map((mo) => (
                <option key={mo} value={mo}>
                  MODE: {mo.toUpperCase()}
                </option>
              ))}
            </select>
          </label>
          <label className="select">
            <span className="sr-only">Station</span>
            <select
              value={filters.station === null ? "*" : filters.station}
              onChange={(e) => setFilters({ ...filters, station: e.target.value === "*" ? null : e.target.value })}
            >
              <option value="*">STATION: ALL</option>
              {stationOptions.map((s) => (
                <option key={s} value={s}>
                  STATION: {s.toUpperCase()}
                </option>
              ))}
              {hasUnrecorded && <option value="">STATION: {NO_STATION.toUpperCase()}</option>}
            </select>
          </label>
          {filtered && (
            <button type="button" className="link-btn" onClick={() => setFilters(ALL)}>
              Reset
            </button>
          )}
        </div>
      </div>

      <section className="strip panel" aria-label="Totals for the selected filters">
        <Figure label="Fill-ups" value={fmt(m.summary.fillUps)} />
        <Figure label="Distance" value={`${fmt(m.summary.distanceKm)} km`} />
        <Figure label="L/100 km" value={fmt(m.summary.litersPer100Km, 2)} accent />
        <Figure label="QAR/km" value={fmt(m.summary.costPerKm, 3)} />
        <Figure label="Spend" value={qar(m.summary.totalSpend)} />
        <Figure label="Avg price paid" value={m.avgPaid ? `${fmt(m.avgPaid, 3)}/L` : "—"} />
      </section>

      {m.list.length === 0 ? (
        <section className="panel">
          <p className="muted">No fill-ups match these filters.</p>
        </section>
      ) : (
        <>
          <section className="row">
            <ModeCard modes={m.modes} />
            <InsightsCard m={m} />
          </section>

          <section className="row">
            <div className="panel panel--wide">
              <div className="panel-head">
                <h2>{data.settings.fuelGrade} price · QAR/L</h2>
                <span className="label">Fuel Prices tab</span>
              </div>
              <SeriesChart
                step
                points={m.prices.map((p) => ({
                  key: p.month,
                  value: p.price,
                  axisLabel: fmtMonth(p.month),
                  readout: (
                    <>
                      <b>{fmtMonthLong(p.month)}</b> · QAR {p.price.toFixed(2)}/L{p.source ? ` · ${p.source}` : ""}
                    </>
                  ),
                }))}
                reference={m.avgPaid ? { value: m.avgPaid, label: `YOUR AVG ${fmt(m.avgPaid, 3)}` } : null}
                highlightKey={m.records.cheapestPrice?.month}
                formatY={(v) => v.toFixed(2)}
                yStep={0.05}
                ariaLabel={`Step chart of the monthly ${data.settings.fuelGrade} price`}
                hint="Tap a month to see its price"
              />
            </div>
          </section>

          <section className="row">
            <div className="panel">
              <div className="panel-head">
                <h2>Km per tank</h2>
                <span className="label">
                  AVG {fmt(m.summary.avgKmPerTank)} · MAX {fmt(m.records.longestTank?.distanceKm)}
                </span>
              </div>
              <ColumnChart
                columns={m.trips.map((e, i) => ({
                  key: e.id,
                  value: e.distanceKm,
                  axisLabel: i === 0 || i === m.trips.length - 1 ? fmtMonth(e.date) : undefined,
                  tone: e.id === m.records.longestTank?.id ? "accent" : e.full ? "accent-2" : "muted",
                  readout: (
                    <>
                      <b>{fmtDate(e.date)}</b> · {fmt(e.distanceKm)} km · {fmt(e.litersPer100Km, 2)} L/100 km{e.full ? "" : " · partial fill"}
                    </>
                  ),
                }))}
                formatY={(v) => fmt(v)}
                yStep={100}
                ariaLabel="Column chart of kilometres per tank"
                hint="Tap a tank to see its distance"
              />
            </div>
            <div className="panel">
              <div className="panel-head">
                <h2>Cumulative spend</h2>
                <span className="label">{qar(m.summary.totalSpend)}</span>
              </div>
              <SeriesChart
                area
                fromZero
                tone="accent-2"
                points={m.cumulative.map((c) => ({
                  key: c.id,
                  value: c.total,
                  axisLabel: fmtMonth(c.date),
                  readout: (
                    <>
                      <b>{fmtDate(c.date)}</b> · +{qar(c.spend)} · total {qar(c.total)}
                    </>
                  ),
                }))}
                formatY={(v) => fmt(v)}
                yStep={m.summary.totalSpend > 1500 ? 500 : m.summary.totalSpend > 400 ? 200 : 50}
                ariaLabel={`Cumulative fuel spend, reaching ${qar(m.summary.totalSpend)}`}
                hint="Tap to see the running total"
              />
            </div>
          </section>

          <StationsCard stations={m.stations} total={m.summary.totalSpend} />

          <section className="row">
            <HeatCard heat={m.heat} average={m.summary.litersPer100Km} />
            <div className="panel">
              <div className="panel-head">
                <h2>How consistent?</h2>
                <span className="label">Tanks per L/100 km band</span>
              </div>
              <ColumnChart
                showValues
                columns={m.bins.map((b, i, all) => ({
                  key: String(b.from),
                  value: b.count,
                  axisLabel: `${b.from.toFixed(1)}${i === all.length - 1 ? "+" : ""}`,
                  tone: b.count === Math.max(...all.map((x) => x.count)) ? "accent" : "accent-2",
                  readout: (
                    <>
                      <b>
                        {b.from.toFixed(1)}–{b.to.toFixed(1)} L/100 km
                      </b>{" "}
                      · {b.count} tank{b.count === 1 ? "" : "s"}
                    </>
                  ),
                }))}
                formatY={(v) => fmt(v)}
                yStep={m.bins.some((b) => b.count > 10) ? 5 : 2}
                ariaLabel="Histogram of tanks by litres per 100 km"
                hint="Tap a band to see how many tanks fell in it"
              />
            </div>
          </section>

          <RecordsCard r={m.records} />
          <TripsTable list={m.list} />
        </>
      )}
    </div>
  );
}

function Figure({ label, value, accent }: { label: string; value: string; accent?: boolean }) {
  return (
    <div className="figure">
      <span className="label">{label}</span>
      <span className={`mono figure__value${accent ? " figure__value--accent" : ""}`}>{value}</span>
    </div>
  );
}

function ModeCard({ modes }: { modes: GroupStats[] }) {
  const values = modes.map((g) => g.litersPer100Km).filter((v): v is number => v !== null);
  const lo = values.length ? Math.floor(Math.min(...values) * 2) / 2 - 0.5 : 0;
  const hi = values.length ? Math.ceil(Math.max(...values) * 2) / 2 + 0.5 : 1;
  const tone = (i: number) => (i === 0 ? "good" : i === modes.length - 1 && modes.length > 1 ? "bad" : "accent-2");
  return (
    <div className="panel">
      <div className="panel-head">
        <h2>Drive mode · L/100 km</h2>
      </div>
      <div className="hbars">
        {modes.map((g, i) => (
          <div key={g.key} className="hbar">
            <div className="hbar__head">
              <span>
                {g.key}{" "}
                <span className="muted small">
                  · {g.trips} trip{g.trips === 1 ? "" : "s"} · {fmt(g.km)} km · {fmt(g.costPerKm, 3)} QAR/km
                </span>
              </span>
              <span className={`mono ${tone(i)}`}>{fmt(g.litersPer100Km, 2)}</span>
            </div>
            <div className="hbar__track">
              <div
                className={`hbar__fill hbar__fill--${tone(i)}`}
                style={{ width: `${g.litersPer100Km === null ? 0 : Math.max(2, ((g.litersPer100Km - lo) / (hi - lo)) * 100)}%` }}
              />
            </div>
          </div>
        ))}
      </div>
      <div className="hbar__axis mono">
        <span>{lo.toFixed(1)}</span>
        <span>{hi.toFixed(1)}</span>
      </div>
    </div>
  );
}

type Model = {
  modes: GroupStats[];
  summer: ReturnType<typeof seasonEfficiency>;
  winter: ReturnType<typeof seasonEfficiency>;
  prices: { month: string; price: number }[];
  records: ReturnType<typeof records>;
  summary: ReturnType<typeof summarize>;
};

function InsightsCard({ m }: { m: Model }) {
  const items: { tone: "good" | "warn" | "info"; text: string }[] = [];
  const ranked = m.modes.filter((g) => g.litersPer100Km !== null && g.trips > 0);
  if (ranked.length > 1) {
    const [best, next] = ranked;
    items.push({
      tone: "good",
      text: `${best!.key} is your most efficient mode, ${fmt(next!.litersPer100Km! - best!.litersPer100Km!, 2)} L/100 km better than ${next!.key}.`,
    });
  }
  if (m.summer.trips && m.winter.trips && m.summer.litersPer100Km && m.winter.litersPer100Km) {
    const diff = m.summer.litersPer100Km - m.winter.litersPer100Km;
    items.push({
      tone: diff > 0 ? "warn" : "info",
      text: `Summer (Jun–Aug) averages ${fmt(m.summer.litersPer100Km, 2)} vs ${fmt(m.winter.litersPer100Km, 2)} in winter (Dec–Mar): ${diff > 0 ? "A/C costs you" : "a difference of"} ${fmt(Math.abs(diff), 2)} L/100 km.`,
    });
  }
  const cheapest = m.records.cheapestPrice;
  const latest = m.prices.at(-1);
  if (cheapest && latest && latest.price > cheapest.price) {
    const pct = ((latest.price - cheapest.price) / cheapest.price) * 100;
    const avgFill = m.summary.fillUps ? m.summary.totalLiters / m.summary.fillUps : 0;
    items.push({
      tone: "info",
      text: `Price is up ${fmt(pct, 1)}% from the ${fmtMonthLong(cheapest.month)} low of QAR ${cheapest.price.toFixed(2)}, about QAR ${fmt((latest.price - cheapest.price) * avgFill, 2)} more per tank.`,
    });
  }
  return (
    <div className="panel">
      <div className="panel-head">
        <h2>Insights</h2>
      </div>
      {items.length ? (
        <ul className="insights">
          {items.map((it) => (
            <li key={it.text} className={`insight insight--${it.tone}`}>
              {it.text}
            </li>
          ))}
        </ul>
      ) : (
        <p className="muted">Not enough trips in this selection for comparisons.</p>
      )}
    </div>
  );
}

function StationsCard({ stations, total }: { stations: GroupStats[]; total: number }) {
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>Stations</h2>
      </div>
      <div className="table-scroll">
        <table className="table">
          <thead>
            <tr>
              <th scope="col">Station</th>
              <th scope="col" className="num">Fills</th>
              <th scope="col" className="num">Litres</th>
              <th scope="col" className="num">QAR</th>
              <th scope="col" className="num">L/100 after</th>
              <th scope="col" className="share-col">Share of spend</th>
            </tr>
          </thead>
          <tbody>
            {stations.map((s) => (
              <tr key={s.key || "none"} className={s.key ? undefined : "muted"}>
                <td>{s.key || NO_STATION}</td>
                <td className="num">{s.fills}</td>
                <td className="num">{fmt(s.liters, 1)}</td>
                <td className="num">{fmt(s.spend, 2)}</td>
                <td className="num">{fmt(s.litersPer100Km, 2)}</td>
                <td className="share-col">
                  <div className="share">
                    <div className="share__fill" style={{ width: `${total ? (s.spend / total) * 100 : 0}%` }} />
                  </div>
                  <span className="small muted">{total ? fmt((s.spend / total) * 100) : 0}%</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function HeatCard({ heat, average }: { heat: ReturnType<typeof efficiencyHeat>; average: number | null }) {
  const tone = (v: number | null) => {
    if (v === null || average === null) return "";
    if (v <= average - 0.25) return "heat--good";
    if (v >= average + 0.25) return "heat--bad";
    return "heat--mid";
  };
  return (
    <div className="panel">
      <div className="panel-head">
        <h2>L/100 km by month</h2>
        <span className="label">By the month a trip started</span>
      </div>
      <div className="table-scroll">
        <table className="heat">
          <thead>
            <tr>
              <th scope="col">
                <span className="sr-only">Year</span>
              </th>
              {MONTH_HEAD.map((h, i) => (
                <th key={i} scope="col">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {heat.map((row) => (
              <tr key={row.year}>
                <th scope="row">{row.year}</th>
                {row.cells.map((c) => (
                  <td
                    key={c.month}
                    className={tone(c.litersPer100Km)}
                    title={c.litersPer100Km === null ? fmtMonthLong(c.month) : `${fmtMonthLong(c.month)}: ${fmt(c.litersPer100Km, 2)} L/100 km over ${c.trips} trip${c.trips === 1 ? "" : "s"}`}
                  >
                    {c.litersPer100Km === null ? "·" : fmt(c.litersPer100Km, 2)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="chart-legend">
        <span className="legend-good">■ ≥0.25 better than avg</span>
        <span>■ near avg {fmt(average, 2)}</span>
        <span className="legend-bad">■ ≥0.25 worse</span>
      </div>
    </div>
  );
}

function RecordsCard({ r }: { r: ReturnType<typeof records> }) {
  const tiles: { label: string; value: string; note: string }[] = [];
  if (r.bestTank) tiles.push({ label: "Best tank", value: fmt(r.bestTank.litersPer100Km, 2), note: `L/100 km · ${fmtDate(r.bestTank.date)}` });
  if (r.worstTank) tiles.push({ label: "Worst tank", value: fmt(r.worstTank.litersPer100Km, 2), note: `L/100 km · ${fmtDate(r.worstTank.date)}${r.worstTank.mode ? ` · ${r.worstTank.mode}` : ""}` });
  if (r.longestTank) tiles.push({ label: "Longest range", value: `${fmt(r.longestTank.distanceKm)} km`, note: `one tank · ${fmtDate(r.longestTank.date)}` });
  if (r.priciestMonth) tiles.push({ label: "Priciest month", value: qar(r.priciestMonth.spend, 0), note: `${fmtMonthLong(r.priciestMonth.month)} · ${r.priciestMonth.fills} fills` });
  if (r.biggestFill) tiles.push({ label: "Biggest fill", value: `${fmt(r.biggestFill.liters, 2)} L`, note: `${fmtDate(r.biggestFill.date)}${r.biggestFill.station ? ` · ${r.biggestFill.station}` : ""}` });
  if (r.cheapestPrice) tiles.push({ label: "Lowest price", value: r.cheapestPrice.price.toFixed(2), note: `QAR/L · ${fmtMonthLong(r.cheapestPrice.month)}` });
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>Records</h2>
      </div>
      <div className="records">
        {tiles.map((t) => (
          <div key={t.label} className="record">
            <span className="label">{t.label}</span>
            <span className="mono record__value">{t.value}</span>
            <span className="kpi__note">{t.note}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

type SortKey = "date" | "distanceKm" | "litersPer100Km" | "totalCost";

function TripsTable({ list }: { list: Entry[] }) {
  const [sort, setSort] = useState<{ key: SortKey; desc: boolean }>({ key: "date", desc: true });
  const rows = useMemo(() => {
    const val = (e: Entry) => (sort.key === "date" ? e.date : (e[sort.key] ?? -Infinity));
    return [...list].sort((a, b) => {
      const va = val(a);
      const vb = val(b);
      return (va < vb ? -1 : va > vb ? 1 : 0) * (sort.desc ? -1 : 1);
    });
  }, [list, sort]);
  const header = (key: SortKey, label: string, num = true) => (
    <th scope="col" className={num ? "num" : undefined} aria-sort={sort.key === key ? (sort.desc ? "descending" : "ascending") : "none"}>
      <button type="button" className="sort-btn" onClick={() => setSort({ key, desc: sort.key === key ? !sort.desc : true })}>
        {label}
        {sort.key === key ? (sort.desc ? " ↓" : " ↑") : ""}
      </button>
    </th>
  );
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>All fill-ups</h2>
        <span className="label">{list.length} rows · tap a column to sort</span>
      </div>
      <div className="table-scroll">
        <table className="table trips">
          <thead>
            <tr>
              {header("date", "Date", false)}
              <th scope="col" className="num">Odometer</th>
              <th scope="col">Station</th>
              <th scope="col">Mode</th>
              <th scope="col" className="num">L</th>
              <th scope="col" className="num">QAR/L</th>
              {header("totalCost", "QAR")}
              {header("distanceKm", "km")}
              {header("litersPer100Km", "L/100")}
              <th scope="col" className="num">QAR/km</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((e) => (
              <tr key={e.id}>
                <td>
                  {fmtDayMonth(e.date)} {e.date.slice(2, 4)}
                </td>
                <td className="num">{fmt(e.odometer)}</td>
                <td>{e.station ?? <span className="muted">—</span>}</td>
                <td>{e.mode ?? "—"}</td>
                <td className="num">{fmt(e.liters, 2)}</td>
                <td className="num">{fmt(e.pricePerLiter, 2)}</td>
                <td className="num">{fmt(e.totalCost, 2)}</td>
                <td className="num">{e.distanceKm === null ? <span className="accent2">open</span> : fmt(e.distanceKm)}</td>
                <td className="num">{fmt(e.litersPer100Km, 2)}</td>
                <td className="num">{fmt(e.costPerKm, 3)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
