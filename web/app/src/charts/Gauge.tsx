const CX = 150;
const CY = 150;
const R = 120;

const point = (t: number, r = R) => {
  const a = Math.PI * (1 - t);
  return [CX + r * Math.cos(a), CY - r * Math.sin(a)] as const;
};

/** Half-circle gauge for L/100 km. Lower is better, so the arc fills from the left. */
export function Gauge({ value, min = 7, max = 12 }: { value: number | null; min?: number; max?: number }) {
  const t = value == null ? 0 : Math.min(1, Math.max(0, (value - min) / (max - min)));
  const [ex, ey] = point(t);
  const [nx, ny] = point(t, R - 20);
  const label = value == null ? "No data yet" : `Gauge: ${value.toFixed(2)} litres per 100 km on a scale from ${min} to ${max}`;
  return (
    <svg viewBox="0 0 300 180" role="img" aria-label={label} className="gauge">
      <path d={`M30 150 A${R} ${R} 0 0 1 270 150`} className="gauge__track" />
      {t > 0 && <path d={`M30 150 A${R} ${R} 0 0 1 ${ex.toFixed(1)} ${ey.toFixed(1)}`} className="gauge__fill" />}
      <line x1={CX} y1={CY} x2={nx.toFixed(1)} y2={ny.toFixed(1)} className="gauge__needle" />
      <circle cx={CX} cy={CY} r="8" className="gauge__hub" />
      <text x="22" y="174" className="chart-label">
        {min}
      </text>
      <text x="266" y="174" className="chart-label">
        {max}
      </text>
    </svg>
  );
}
