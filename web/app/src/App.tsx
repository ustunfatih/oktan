import { useEffect, useState, type ComponentType } from "react";
import { DataProvider, useData } from "./data";
import { fmt, fmtAgo } from "./format";
import { BarsIcon, DropIcon, GaugeIcon, GearIcon, PlusIcon, RefreshIcon } from "./icons";
import { Dashboard } from "./pages/Dashboard";
import { ComingSoon } from "./pages/ComingSoon";
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
  return (
    <div className="shell">
      <TopBar />
      <main className="page">
        {route === "/" && <Dashboard />}
        {route === "/analytics" && <ComingSoon title="Analytics" phase="phase 4" />}
        {route === "/log" && <ComingSoon title="Log fill-up" phase="phase 5" />}
        {route === "/settings" && <ComingSoon title="Settings" phase="phase 6b" />}
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
