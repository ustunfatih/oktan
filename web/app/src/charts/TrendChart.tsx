import { useState, type KeyboardEvent, type PointerEvent } from "react";
import type { TrendPoint } from "../../../shared/dashboard";
import { fmt, fmtDate, fmtMonth } from "../format";
import { useWidth } from "./useWidth";

interface Props {
  points: TrendPoint[];
  average: number | null;
  best: TrendPoint | null;
  worst: TrendPoint | null;
}

const PAD = { top: 18, right: 14, bottom: 26, left: 38 };

/** L/100 km per tank. Tap, hover or use the arrow keys to read a point. */
export function TrendChart({ points, average, best, worst }: Props) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [selected, setSelected] = useState<number | null>(null);
  const height = width < 520 ? 180 : 230;

  if (points.length < 2) return <div ref={ref} className="chart-empty">Not enough completed trips yet.</div>;

  const values = points.map((p) => p.value);
  const lo = Math.floor((Math.min(...values) - 0.2) * 2) / 2;
  const hi = Math.ceil((Math.max(...values) + 0.2) * 2) / 2;
  const plotW = width - PAD.left - PAD.right;
  const plotH = height - PAD.top - PAD.bottom;
  const x = (i: number) => PAD.left + (plotW * i) / (points.length - 1);
  const y = (v: number) => PAD.top + plotH * (1 - (v - lo) / (hi - lo));

  const line = points.map((p, i) => `${i ? "L" : "M"}${x(i).toFixed(1)} ${y(p.value).toFixed(1)}`).join(" ");
  const area = `${line} L${x(points.length - 1).toFixed(1)} ${PAD.top + plotH} L${PAD.left} ${PAD.top + plotH} Z`;
  const grid: number[] = [];
  for (let v = lo; v <= hi + 1e-9; v += 0.5) grid.push(Math.round(v * 10) / 10);

  const pick = (e: PointerEvent<SVGSVGElement>) => {
    const box = e.currentTarget.getBoundingClientRect();
    const px = ((e.clientX - box.left) / box.width) * width;
    const i = Math.round(((px - PAD.left) / plotW) * (points.length - 1));
    setSelected(Math.min(points.length - 1, Math.max(0, i)));
  };
  const onKey = (e: KeyboardEvent) => {
    if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
    e.preventDefault();
    const cur = selected ?? points.length - 1;
    setSelected(Math.min(points.length - 1, Math.max(0, cur + (e.key === "ArrowRight" ? 1 : -1))));
  };

  const sel = selected === null ? null : points[selected]!;
  const idx = (p: TrendPoint | null) => (p ? points.findIndex((q) => q.id === p.id) : -1);
  const bi = idx(best);
  const wi = idx(worst);
  const li = points.length - 1;

  return (
    <div ref={ref} className="chart">
      <p className="chart-readout" aria-live="polite">
        {sel ? (
          <>
            <b>{fmtDate(sel.date)}</b> · {fmt(sel.value, 2)} L/100 km · {fmt(sel.km)} km
            {sel.station ? ` · ${sel.station}` : ""}
            {sel.mode ? ` · ${sel.mode}` : ""}
          </>
        ) : (
          <span className="muted">Tap the chart to read a tank</span>
        )}
      </p>
      <svg
        width={width}
        height={height}
        role="img"
        aria-label={`Line chart of litres per 100 km for ${points.length} tanks, from ${fmt(Math.min(...values), 2)} to ${fmt(Math.max(...values), 2)}`}
        tabIndex={0}
        onPointerDown={pick}
        onPointerMove={(e) => e.pointerType === "mouse" && pick(e)}
        onPointerLeave={(e) => e.pointerType === "mouse" && setSelected(null)}
        onKeyDown={onKey}
        className="chart-svg"
      >
        {grid.map((v) => (
          <g key={v}>
            <line x1={PAD.left} x2={width - PAD.right} y1={y(v)} y2={y(v)} className="chart-grid" />
            <text x={PAD.left - 8} y={y(v) + 4} textAnchor="end" className="chart-label">
              {v.toFixed(1)}
            </text>
          </g>
        ))}
        <path d={area} className="trend__area" />
        {average !== null && (
          <line x1={PAD.left} x2={width - PAD.right} y1={y(average)} y2={y(average)} className="trend__avg" />
        )}
        <path d={line} className="trend__line" />
        {bi >= 0 && <circle cx={x(bi)} cy={y(points[bi]!.value)} r="5" className="dot-good" />}
        {wi >= 0 && <circle cx={x(wi)} cy={y(points[wi]!.value)} r="5" className="dot-bad" />}
        <circle cx={x(li)} cy={y(points[li]!.value)} r="5" className="trend__last" />
        {sel && selected !== null && (
          <g>
            <line x1={x(selected)} x2={x(selected)} y1={PAD.top} y2={PAD.top + plotH} className="chart-guide" />
            <circle cx={x(selected)} cy={y(sel.value)} r="6" className="trend__sel" />
          </g>
        )}
        <text x={PAD.left} y={height - 6} className="chart-label">
          {fmtMonth(points[0]!.date)}
        </text>
        <text x={width - PAD.right} y={height - 6} textAnchor="end" className="chart-label">
          {fmtMonth(points[li]!.date)}
        </text>
      </svg>
      <div className="chart-legend">
        <span className="legend-line">━ per tank</span>
        {average !== null && <span className="legend-avg">┅ avg {fmt(average, 2)}</span>}
        {best && <span className="legend-good">● best {fmt(best.value, 2)} · {fmtMonth(best.date)}</span>}
        {worst && <span className="legend-bad">● worst {fmt(worst.value, 2)} · {fmtMonth(worst.date)}</span>}
      </div>
    </div>
  );
}
