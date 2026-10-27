// Runs before the first paint. Kept in its own file so the Content-Security-Policy needs no 'unsafe-inline'
// scripts. Applies the last theme (or, on a first visit, the Auto pick for the phone's dark/light setting),
// and marks a Home Screen launch so the splash shows only there. The app re-checks the theme once the sheet
// is read.
try {
  var root = document.documentElement;
  var t = JSON.parse(localStorage.getItem("oktan:theme-applied") || "null");
  if (t && t.theme) root.dataset.theme = t.theme;
  else root.dataset.theme = matchMedia("(prefers-color-scheme: dark)").matches ? "cluster" : "fintech";
  if (navigator.standalone === true || matchMedia("(display-mode: standalone)").matches) root.classList.add("standalone");
} catch (e) {}
