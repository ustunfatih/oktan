import { lazy, Suspense, useEffect, useState, type ComponentType } from "react";
import { DataProvider, useData } from "./data";
import { ErrorBoundary } from "./ErrorBoundary";
import { fmt, fmtAgo } from "./format";
import { BarsIcon, DropIcon, GaugeIcon, GearIcon, PlusIcon, RefreshIcon, WrenchIcon } from "./icons";
import { Dashboard } from "./pages/Dashboard";
// Only the dashboard is needed on first load; the other pages are fetched the first time they're opened.
const Analytics = lazy(() => import("./pages/Analytics").then((m) => ({ default: m.Analytics })));
const Log = lazy(() => import("./pages/Log").then((m) => ({ default: m.Log })));
const Settings = lazy(() => import("./pages/Settings").then((m) => ({ default: m.Settings })));
const Service = lazy(() => import("./pages/Service").then((m) => ({ default: m.Service })));
import { useAppliedTheme } from "./theme";
import { hideSplash } from "./splash";
import { Link, RouterProvider, useRouter, type Route } from "./router";

const TABS: { to: Route; label: string; icon: ComponentType }[] = [
  { to: "/", label: "Dashboard", icon: GaugeIcon },
  { to: "/analytics", label: "Analytics", icon: BarsIcon },
  { to: "/log", label: "Log fill-up", icon: PlusIcon },
  { to: "/service", label: "Service", icon: WrenchIcon },
];

export function App() {
  return (
    <RouterProvider>
      <DataProvider>
        <Shell />
      </DataProvider>
    </RouterProvider>
  );
}

function Shell() {
  const { route } = useRouter();
  const { data, error } = useData();
  useAppliedTheme(data?.settings.theme);
  // The launch splash goes once there's something to show: the sheet's numbers, or an error to explain.
  const ready = data !== null || error !== null;
  useEffect(() => {
    if (ready) hideSplash();
  }, [ready]);
  return (
    <div className="shell">
      <a className="skip-link" href="#main">Skip to content</a>
      <TopBar />
      <TestModeStrip />
      <main id="main" className="page" tabIndex={-1}>
        <ErrorBoundary resetKey={`${route} ${data?.fetchedAt ?? ""}`}>
          <Suspense fallback={<p className="muted page-loading" role="status">Loading…</p>}>
            {route === "/" && <Dashboard />}
            {route === "/analytics" && <Analytics />}
            {route === "/log" && <Log />}
            {route === "/service" && <Service />}
            {route === "/settings" && <Settings />}
          </Suspense>
        </ErrorBoundary>
      </main>
      <nav className="bottom-nav" aria-label="Main">
        {TABS.map(({ to, label, icon: Icon }) => (
          <Link key={to} to={to} className="bottom-nav__item">
            <Icon />
            <span>{to === "/log" ? "Log" : label}</span>
          </Link>
        ))}
      </nav>
    </div>
  );
}

/** Always visible while the app is pointed at the DEV copy, so test data is never mistaken for real. */
function TestModeStrip() {
  const { data, setSheet, loading } = useData();
  if (!data || data.sheet !== "dev" || !data.testModeAvailable) return null;
  return (
    <div className="test-strip" role="status">
      <span>TEST MODE · OKTAN DEV SHEET</span>
      <button type="button" className="link-btn" disabled={loading} onClick={() => setSheet("live")}>
        Back to live
      </button>
    </div>
  );
}

function TopBar() {
  const { data, loading, refresh, pending } = useData();
  const [, tick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => tick((n) => n + 1), 30_000);
    return () => clearInterval(id);
  }, []);

  const odometer = data?.entries.at(-1)?.odometer;

  return (
    <header className="topbar">
      <Link to="/" className="brand" aria-label="Oktan home">
        <DropIcon />
        <span>OKTAN</span>
      </Link>

      <nav className="tabs" aria-label="Main">
        {TABS.map(({ to, label }) => (
          <Link key={to} to={to} className="tabs__item">
            {label}
          </Link>
        ))}
      </nav>

      <div className="topbar__end">
        {pending.length > 0 && (
          <span className="chip chip--waiting" role="status">
            {pending.length} WAITING
          </span>
        )}
        {data && (
          <span className="chip" title={`Read ${new Date(data.fetchedAt).toLocaleString("en-GB")}`}>
            <span className={`dot ${data.sheet === "live" ? "dot--ok" : "dot--dev"}`} />
            <span className="chip__long">{data.sheet === "live" ? "SHEET" : "DEV SHEET"} · </span>
            {loading ? "SYNCING…" : fmtAgo(data.fetchedAt).toUpperCase()}
          </span>
        )}
        {odometer != null && <span className="chip chip__long">ODO {fmt(odometer)} KM</span>}
        <button type="button" className="icon-btn" onClick={refresh} disabled={loading} aria-label="Refresh from the sheet">
          <span className={loading ? "spin" : undefined}>
            <RefreshIcon />
          </span>
        </button>
        <Link to="/settings" className="icon-btn" aria-label="Settings">
          <GearIcon />
        </Link>
      </div>
    </header>
  );
}
