import { useState, type KeyboardEvent, type PointerEvent, type ReactNode } from "react";
import { ChartTable } from "./ChartTable";
import { niceStep, robustRange } from "../../../shared/scale";
import { useWidth } from "./useWidth";

export interface SeriesPoint {
  key: string;
  value: number;
  /** Text under the x axis for the first and last points. */
  axisLabel: string;
  /** Shown above the chart when the point is selected. */
  readout: ReactNode;
}

interface Props {
  points: SeriesPoint[];
  /** Draw as a step line (for monthly prices) instead of straight segments. */
  step?: boolean;
  area?: boolean;
  /** Dashed reference line, e.g. an average. */
  reference?: { value: number; label: string } | null;
  /** Highlighted point (e.g. the low), drawn in the "good" colour. */
  highlightKey?: string | null;
  formatY: (v: number) => string;
  /** Distance between grid lines in data units. */
  yStep: number;
  /** Start the y axis at zero (totals) instead of fitting the data (rates). */
  fromZero?: boolean;
  ariaLabel: string;
  hint: string;
  tone?: "accent" | "accent-2";
}

const PAD = { top: 16, right: 14, bottom: 26, left: 44 };

/** Line or step chart with tap/hover/arrow-key readout, drawn at real pixel width. */
export function SeriesChart({ points, step, area, reference, highlightKey, formatY, yStep, fromZero, ariaLabel, hint, tone = "accent" }: Props) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [selected, setSelected] = useState<number | null>(null);
  const height = width < 520 ? 170 : 220;

  if (points.length < 2) return <div ref={ref} className="chart-empty">Not enough data in this range.</div>;

  const values = points.map((p) => p.value).concat(reference ? [reference.value] : []);
  // Outliers don't stretch the axis (they're drawn at the edge, marked), and the grid never gets crowded.
  const fitted = fromZero ? null : robustRange(values, yStep, 5);
  const gridStep = Math.max(yStep, niceStep(fitted ? fitted.hi - fitted.lo : Math.max(...values), 5));
  const lo = fitted ? Math.floor(fitted.lo / gridStep) * gridStep : 0;
  const hi = Math.ceil((fitted ? fitted.hi : Math.max(...values)) / gridStep) * gridStep;
  const offScale = (v: number) => !!fitted && fitted.outliers.has(v);
  const plotW = width - PAD.left - PAD.right;
  const plotH = height - PAD.top - PAD.bottom;
  const x = (i: number) => PAD.left + (plotW * i) / (points.length - 1);
  const y = (v: number) => PAD.top + plotH * (1 - (Math.min(hi, Math.max(lo, v)) - lo) / (hi - lo || 1));

  let d = `M${x(0).toFixed(1)} ${y(points[0]!.value).toFixed(1)}`;
  points.slice(1).forEach((p, j) => {
    const i = j + 1;
    d += step ? ` H${x(i).toFixed(1)} V${y(p.value).toFixed(1)}` : ` L${x(i).toFixed(1)} ${y(p.value).toFixed(1)}`;
  });
  const fill = `${d} L${x(points.length - 1).toFixed(1)} ${PAD.top + plotH} L${PAD.left} ${PAD.top + plotH} Z`;
  const grid: number[] = [];
  for (let v = lo; v <= hi + gridStep * 1e-6; v += gridStep) grid.push(Math.round(v * 1000) / 1000);

  const pick = (e: PointerEvent<SVGSVGElement>) => {
    const box = e.currentTarget.getBoundingClientRect();
    const px = ((e.clientX - box.left) / box.width) * width;
    setSelected(Math.min(points.length - 1, Math.max(0, Math.round(((px - PAD.left) / plotW) * (points.length - 1)))));
  };
  const onKey = (e: KeyboardEvent) => {
    if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
    e.preventDefault();
    const cur = selected ?? points.length - 1;
    setSelected(Math.min(points.length - 1, Math.max(0, cur + (e.key === "ArrowRight" ? 1 : -1))));
  };
  const sel = selected === null ? null : points[selected]!;
  const hi_ = highlightKey ? points.findIndex((p) => p.key === highlightKey) : -1;
  const li = points.length - 1;

  return (
    <div ref={ref} className="chart">
      <p className="chart-readout" aria-live="polite">
        {sel ? sel.readout : <span className="muted">{hint}</span>}
      </p>
      <svg
        width={width}
        height={height}
        role="img"
        aria-label={ariaLabel}
        tabIndex={0}
        onPointerDown={pick}
        onPointerMove={(e) => e.pointerType === "mouse" && pick(e)}
        onPointerLeave={(e) => e.pointerType === "mouse" && setSelected(null)}
        onKeyDown={onKey}
        className={`chart-svg series series--${tone}`}
      >
        {grid.map((v) => (
          <g key={v}>
            <line x1={PAD.left} x2={width - PAD.right} y1={y(v)} y2={y(v)} className="chart-grid" />
            <text x={PAD.left - 8} y={y(v) + 4} textAnchor="end" className="chart-label">
              {formatY(v)}
            </text>
          </g>
        ))}
        {area && <path d={fill} className="series__area" />}
        {reference && (
          <g>
            <line x1={PAD.left} x2={width - PAD.right} y1={y(reference.value)} y2={y(reference.value)} className="series__ref" />
            <text x={width - PAD.right} y={y(reference.value) - 6} textAnchor="end" className="chart-label series__ref-label">
              {reference.label}
            </text>
          </g>
        )}
        <path d={d} className="series__line" />
        {hi_ >= 0 && <circle cx={x(hi_)} cy={y(points[hi_]!.value)} r="5" className="dot-good" />}
        <circle cx={x(li)} cy={y(points[li]!.value)} r="4.5" className="series__last" />
        {sel && selected !== null && (
          <g>
            <line x1={x(selected)} x2={x(selected)} y1={PAD.top} y2={PAD.top + plotH} className="chart-guide" />
            <circle cx={x(selected)} cy={y(sel.value)} r="6" className="series__sel" />
          </g>
        )}
        {points.map((p, i) =>
          offScale(p.value) ? (
            <text key={`off-${i}`} x={x(i)} y={y(p.value) + (p.value > hi ? 14 : -6)} textAnchor="middle" className="chart-label">
              {p.value > hi ? "▲" : "▼"}
            </text>
          ) : null,
        )}
        <text x={PAD.left} y={height - 6} className="chart-label">
          {points[0]!.axisLabel}
        </text>
        <text x={width - PAD.right} y={height - 6} textAnchor="end" className="chart-label">
          {points[li]!.axisLabel}
        </text>
      </svg>
      <ChartTable caption={ariaLabel} head={["Point", "Value"]} rows={points.map((p) => [p.axisLabel || p.key, formatY(p.value)])} />
    </div>
  );
}
