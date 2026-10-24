import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { reportClientError } from "./report";
import "./styles.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

// Offline shell for the home-screen app (production builds only; dev servers change files constantly).
if ("serviceWorker" in navigator && import.meta.env.PROD) {
  addEventListener("load", () => navigator.serviceWorker.register("/sw.js").catch(() => {}));
}

// Errors outside React rendering (event handlers, promises) go to the Worker logs too.
addEventListener("error", (e) => reportClientError("window", e.error ?? e.message));
addEventListener("unhandledrejection", (e) => {
  // Refused API calls are shown in the app already; only report real exceptions.
  if (e.reason instanceof Error) reportClientError("promise", e.reason);
});
