import { createContext, useContext, useEffect, useState, type AnchorHTMLAttributes, type ReactNode } from "react";

export type Route = "/" | "/analytics" | "/log" | "/settings";
const ROUTES: Route[] = ["/", "/analytics", "/log", "/settings"];

const toRoute = (path: string): Route => (ROUTES.includes(path as Route) ? (path as Route) : "/");

const RouterContext = createContext<{ route: Route; go: (to: Route) => void }>({ route: "/", go: () => {} });

export function RouterProvider({ children }: { children: ReactNode }) {
  const [route, setRoute] = useState<Route>(() => toRoute(location.pathname));

  useEffect(() => {
    const onPop = () => setRoute(toRoute(location.pathname));
    addEventListener("popstate", onPop);
    return () => removeEventListener("popstate", onPop);
  }, []);

  const go = (to: Route) => {
    if (to !== route) history.pushState(null, "", to);
    setRoute(to);
    scrollTo({ top: 0 });
  };

  return <RouterContext.Provider value={{ route, go }}>{children}</RouterContext.Provider>;
}

export const useRouter = () => useContext(RouterContext);

/** An <a> that navigates inside the app without a page load. */
export function Link({ to, ...props }: { to: Route } & AnchorHTMLAttributes<HTMLAnchorElement>) {
  const { route, go } = useRouter();
  return (
    <a
      {...props}
      href={to}
      aria-current={route === to ? "page" : undefined}
      onClick={(e) => {
        if (e.metaKey || e.ctrlKey || e.shiftKey || e.button !== 0) return;
        e.preventDefault();
        go(to);
      }}
    />
  );
}
