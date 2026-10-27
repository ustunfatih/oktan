import { useState, type KeyboardEvent } from "react";
import type { MonthTotal } from "../../../shared/dashboard";
import { fmtMonth, fmtMonthLong, qar } from "../format";
import { ChartTable } from "./ChartTable";
import { useWidth } from "./useWidth";

const PAD = { top: 12, right: 8, bottom: 26, left: 38 };

/** Spend per month. Bars for the current year are highlighted; the current month stands out. */
export function MonthlyBars({ months, currentMonth }: { months: MonthTotal[]; currentMonth: string }) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [selected, setSelected] = useState<number | null>(null);
  const height = width < 520 ? 170 : 220;

  if (!months.length) return <div ref={ref} className="chart-empty">No fill-ups yet.</div>;

  const maxSpend = Math.max(...months.map((m) => m.spend), 1);
  const step = maxSpend > 150 ? 50 : maxSpend > 60 ? 25 : 10;
  const top = Math.ceil(maxSpend / step) * step;
  const plotW = width - PAD.left - PAD.right;
  const plotH = height - PAD.top - PAD.bottom;
  const slot = plotW / months.length;
  const barW = Math.max(3, Math.min(28, slot * 0.62));
  const y = (v: number) => PAD.top + plotH * (1 - v / top);
  const thisYear = currentMonth.slice(0, 4);
  const grid: number[] = [];
  for (let v = step; v <= top; v += step) grid.push(v);

  const sel = selected === null ? null : months[selected]!;
  const onKey = (e: KeyboardEvent) => {
    if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
    e.preventDefault();
    const cur = selected ?? months.length - 1;
    setSelected(Math.min(months.length - 1, Math.max(0, cur + (e.key === "ArrowRight" ? 1 : -1))));
  };
  const label = (i: number) => i === 0 || i === months.length - 1 || months[i]!.month.endsWith("-01");

  return (
    <div ref={ref} className="chart">
      <p className="chart-readout" aria-live="polite">
        {sel ? (
          <>
            <b>{fmtMonthLong(sel.month)}</b> · {qar(sel.spend)} · {sel.fills} fill-up{sel.fills === 1 ? "" : "s"}
          </>
        ) : (
          <span className="muted">Tap a month to see its total</span>
        )}
      </p>
      <svg
        width={width}
        height={height}
        role="img"
        aria-label={`Bar chart of fuel spend per month, ${months.length} months`}
        tabIndex={0}
        onKeyDown={onKey}
        onPointerLeave={(e) => e.pointerType === "mouse" && setSelected(null)}
        className="chart-svg"
      >
        {grid.map((v) => (
          <g key={v}>
            <line x1={PAD.left} x2={width - PAD.right} y1={y(v)} y2={y(v)} className="chart-grid" />
            <text x={PAD.left - 8} y={y(v) + 4} textAnchor="end" className="chart-label">
              {v}
            </text>
          </g>
        ))}
        {months.map((m, i) => {
          const cx = PAD.left + slot * i + slot / 2;
          const cls =
            m.month === currentMonth ? "bar bar--now" : m.month.startsWith(thisYear) ? "bar bar--year" : "bar";
          return (
            <g
              key={m.month}
              onPointerDown={() => setSelected(i)}
              onPointerEnter={(e) => e.pointerType === "mouse" && setSelected(i)}
            >
              <rect x={PAD.left + slot * i} y={PAD.top} width={slot} height={plotH} fill="transparent" />
              {m.spend > 0 && (
                <rect
                  x={cx - barW / 2}
                  y={y(m.spend)}
                  width={barW}
                  height={PAD.top + plotH - y(m.spend)}
                  rx="3"
                  className={`${cls}${selected === i ? " bar--sel" : ""}`}
                />
              )}
              {label(i) && (
                <text
                  // The outermost labels hug the edges so they are never clipped.
                  x={i === 0 ? PAD.left + slot * i : i === months.length - 1 ? PAD.left + slot * (i + 1) : cx}
                  y={height - 6}
                  textAnchor={i === 0 ? "start" : i === months.length - 1 ? "end" : "middle"}
                  className={`chart-label${m.month === currentMonth ? " label-now" : ""}`}
                >
                  {fmtMonth(m.month)}
                </text>
              )}
            </g>
          );
        })}
      </svg>
      <ChartTable
        caption="Spend per month"
        head={["Month", "Spend", "Fill-ups"]}
        rows={months.map((m) => [fmtMonthLong(m.month), qar(m.spend), m.fills])}
      />
    </div>
  );
}
