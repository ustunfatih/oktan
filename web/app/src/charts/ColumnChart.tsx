import { useState, type KeyboardEvent, type ReactNode } from "react";
import { useWidth } from "./useWidth";

export interface Column {
  key: string;
  value: number;
  /** Label under the column; omit to leave it unlabelled. */
  axisLabel?: string;
  readout: ReactNode;
  tone?: "accent" | "accent-2" | "muted" | "good" | "bad";
}

interface Props {
  columns: Column[];
  formatY: (v: number) => string;
  yStep: number;
  ariaLabel: string;
  hint: string;
  /** Print each column's value above it (for few, wide columns such as a histogram). */
  showValues?: boolean;
}

const PAD = { top: 18, right: 8, bottom: 26, left: 40 };

/** Vertical bars with tap/hover/arrow-key readout, drawn at real pixel width. */
export function ColumnChart({ columns, formatY, yStep, ariaLabel, hint, showValues }: Props) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [selected, setSelected] = useState<number | null>(null);
  const height = width < 520 ? 170 : 220;

  if (!columns.length) return <div ref={ref} className="chart-empty">No data in this range.</div>;

  const top = Math.max(yStep, Math.ceil(Math.max(...columns.map((c) => c.value)) / yStep) * yStep);
  const plotW = width - PAD.left - PAD.right;
  const plotH = height - PAD.top - PAD.bottom;
  const slot = plotW / columns.length;
  const barW = Math.max(3, Math.min(showValues ? 64 : 26, slot * 0.64));
  const y = (v: number) => PAD.top + plotH * (1 - v / top);
  const grid: number[] = [];
  for (let v = yStep; v <= top + 1e-9; v += yStep) grid.push(Math.round(v * 1000) / 1000);
  const sel = selected === null ? null : columns[selected]!;
  const onKey = (e: KeyboardEvent) => {
    if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
    e.preventDefault();
    const cur = selected ?? columns.length - 1;
    setSelected(Math.min(columns.length - 1, Math.max(0, cur + (e.key === "ArrowRight" ? 1 : -1))));
  };

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
        onKeyDown={onKey}
        onPointerLeave={(e) => e.pointerType === "mouse" && setSelected(null)}
        className="chart-svg"
      >
        {grid.map((v) => (
          <g key={v}>
            <line x1={PAD.left} x2={width - PAD.right} y1={y(v)} y2={y(v)} className="chart-grid" />
            <text x={PAD.left - 8} y={y(v) + 4} textAnchor="end" className="chart-label">
              {formatY(v)}
            </text>
          </g>
        ))}
        {columns.map((c, i) => {
          const cx = PAD.left + slot * i + slot / 2;
          const first = i === 0;
          const last = i === columns.length - 1;
          return (
            <g key={c.key} onPointerDown={() => setSelected(i)} onPointerEnter={(e) => e.pointerType === "mouse" && setSelected(i)}>
              <rect x={PAD.left + slot * i} y={PAD.top} width={slot} height={plotH} fill="transparent" />
              {c.value > 0 && (
                <rect
                  x={cx - barW / 2}
                  y={y(c.value)}
                  width={barW}
                  height={PAD.top + plotH - y(c.value)}
                  rx="3"
                  className={`col col--${c.tone ?? "accent-2"}${selected === i ? " bar--sel" : ""}`}
                />
              )}
              {showValues && c.value > 0 && (
                <text x={cx} y={y(c.value) - 6} textAnchor="middle" className="chart-label col__value">
                  {formatY(c.value)}
                </text>
              )}
              {c.axisLabel && (
                <text
                  x={showValues ? cx : first ? PAD.left + slot * i : last ? PAD.left + slot * (i + 1) : cx}
                  y={height - 6}
                  textAnchor={showValues ? "middle" : first ? "start" : last ? "end" : "middle"}
                  className="chart-label"
                >
                  {c.axisLabel}
                </text>
              )}
            </g>
          );
        })}
      </svg>
    </div>
  );
}
