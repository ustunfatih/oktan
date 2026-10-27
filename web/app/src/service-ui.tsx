import type { DueItem, ServiceJob } from "../../shared/maintenance";
import type { ServiceState } from "../../shared/types";
import { Link } from "./router";
import { fmt, fmtDate } from "./format";

/** Light enough to load with the dashboard; the full Service page is fetched only when opened. */

const STATUS_WORD = { overdue: "Overdue", soon: "Due soon", ok: "OK" } as const;

/** "1,200 km left · 45 days (14 Dec)", or the overdue equivalent. */
export function dueText(i: DueItem): string {
  const parts: string[] = [];
  if (i.kmLeft !== null) parts.push(i.kmLeft <= 0 ? `${fmt(-i.kmLeft)} km over` : `${fmt(i.kmLeft)} km left`);
  if (i.daysLeft !== null && i.dueDate) {
    if (i.daysLeft < 0) parts.push(`${fmt(-i.daysLeft)} days over`);
    else if (i.daysLeft === 0) parts.push("due today");
    else parts.push(`${fmt(i.daysLeft)} days (${fmtDate(i.dueDate)})`);
  }
  return parts.join(" · ");
}

/** The four services due soonest, with their status written out (not only coloured). */
export function NextServicePanel({ service }: { service: ServiceState }) {
  const items = service.due.slice(0, 4);
  return (
    <section className="panel next-service">
      <div className="panel-head">
        <h2>Next service</h2>
        <Link to="/service" className="link-btn">
          Service
        </Link>
      </div>
      {items.length === 0 ? (
        <p className="muted">
          {service.jobs.length
            ? "Nothing with an interval is due yet. Set intervals in Service → Plan."
            : "No service recorded yet. Add one on the Service tab."}
        </p>
      ) : (
        <ul className="due-list">
          {items.map((i) => (
            <li key={i.category} className={`due due--${i.status}`}>
              <div className="due__name">
                <b>{i.category}</b>
                <span className="muted small">
                  last {fmtDate(i.last.date)} at {fmt(i.last.odometer)} km
                </span>
              </div>
              <div className="due__when">
                <span className="due__status">{STATUS_WORD[i.status]}</span> · {dueText(i)}
              </div>
            </li>
          ))}
        </ul>
      )}
      {service.skipped > 0 && (
        <p className="muted small">
          {service.skipped} row{service.skipped === 1 ? "" : "s"} in the Maintenance tab can't be read (no date, category or odometer). Fix them in the sheet.
        </p>
      )}
    </section>
  );
}

/** Jobs on or after the start of an analytics range (null means all time). */
export function jobsInRange(jobs: ServiceJob[], from: string | null): ServiceJob[] {
  return jobs.filter((j) => !from || j.date >= from);
}
