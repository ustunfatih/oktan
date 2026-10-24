import { useEffect, useState, type ComponentType } from "react";
import { DataProvider, useData } from "./data";
import { fmt, fmtAgo } from "./format";
import { BarsIcon, DropIcon, GaugeIcon, GearIcon, PlusIcon, RefreshIcon } from "./icons";
import { Dashboard } from "./pages/Dashboard";
import { Analytics } from "./pages/Analytics";
import { Log } from "./pages/Log";
import { Settings } from "./pages/Settings";
import { useAppliedTheme } from "./theme";
import { Link, RouterProvider, useRouter, type Route } from "./router";

const TABS: { to: Route; label: string; icon: ComponentType }[] = [
  { to: "/", label: "Dashboard", icon: GaugeIcon },
  { to: "/analytics", label: "Analytics", icon: BarsIcon },
  { to: "/log", label: "Log fill-up", icon: PlusIcon },
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
  const { data } = useData();
  useAppliedTheme(data?.settings.theme);
  return (
    <div className="shell">
      <TopBar />
      <TestModeStrip />
      <main className="page">
        {route === "/" && <Dashboard />}
        {route === "/analytics" && <Analytics />}
        {route === "/log" && <Log />}
        {route === "/settings" && <Settings />}
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
  const { data, loading, refresh } = useData();
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
