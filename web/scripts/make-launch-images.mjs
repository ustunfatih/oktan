// Makes the iPhone launch images (the static frame iOS shows before the app starts) and wires them into
// app/index.html. Option B: the gauge at its final reading, placed exactly where the in-app splash draws it,
// so the hand-over is seamless. No text: Apple's guidance is to keep launch screens free of words.
//
//   node scripts/make-launch-images.mjs
//
// Re-run after changing the splash geometry in styles.css or the colours below.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { Resvg } from "@resvg/resvg-js";

// Portrait screens: CSS size, pixel ratio. iOS picks the image whose media query matches exactly.
const DEVICES = [
  { w: 440, h: 956, dpr: 3, note: "iPhone 16 Pro Max" },
  { w: 402, h: 874, dpr: 3, note: "iPhone 16 Pro" },
  { w: 430, h: 932, dpr: 3, note: "iPhone 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus" },
  { w: 393, h: 852, dpr: 3, note: "iPhone 14 Pro, 15, 15 Pro, 16" },
  { w: 428, h: 926, dpr: 3, note: "iPhone 12 Pro Max, 13 Pro Max, 14 Plus" },
  { w: 390, h: 844, dpr: 3, note: "iPhone 12, 12 Pro, 13, 13 Pro, 14" },
  { w: 375, h: 812, dpr: 3, note: "iPhone X, XS, 11 Pro, 12 mini, 13 mini" },
  { w: 414, h: 896, dpr: 3, note: "iPhone XS Max, 11 Pro Max" },
  { w: 414, h: 896, dpr: 2, note: "iPhone XR, 11" },
  { w: 375, h: 667, dpr: 2, note: "iPhone SE (2nd and 3rd generation), 8" },
];

// Light and dark follow the phone's setting, matching the app's Auto theme (Soft Fintech / Instrument Cluster).
const SCHEMES = {
  light: { bg: "#f4f6fb", accent: "#4f46e5", text: "#0f172a" },
  dark: { bg: "#0a0c0f", accent: "#ffb547", text: "#e8ecf1" },
};

// Must match .splash in styles.css: gauge width min(56vw, 220px), 22px gap, then the 17px wordmark (~20px line).
const GAP = 22;
const WORD_LINE = 20;
const READING = 0.72;
const ARC = Math.PI * 60; // the arc is a half circle of radius 60 in the gauge's 150x100 box

function svg(device, c) {
  const W = device.w * device.dpr;
  const H = device.h * device.dpr;
  const gaugeW = Math.min(device.w * 0.56, 220);
  const gaugeH = (gaugeW * 100) / 150;
  const top = (device.h - (gaugeH + GAP + WORD_LINE)) / 2;
  const left = (device.w - gaugeW) / 2;
  const s = (gaugeW / 150) * device.dpr;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <rect width="${W}" height="${H}" fill="${c.bg}"/>
  <g transform="translate(${left * device.dpr} ${top * device.dpr}) scale(${s})">
    <path d="M15 90 A60 60 0 0 1 135 90" fill="none" stroke="${c.text}" stroke-opacity="0.15" stroke-width="9" stroke-linecap="round"/>
    <path d="M15 90 A60 60 0 0 1 135 90" fill="none" stroke="${c.accent}" stroke-width="9" stroke-linecap="round" stroke-dasharray="${ARC}" stroke-dashoffset="${ARC * (1 - READING)}"/>
    <line x1="27" y1="90" x2="75" y2="90" stroke="${c.text}" stroke-width="3" stroke-linecap="round" transform="rotate(${READING * 180} 75 90)"/>
    <circle cx="75" cy="90" r="5" fill="${c.text}"/>
  </g>
</svg>`;
}

mkdirSync("app/public/splash", { recursive: true });
const links = [];
for (const d of DEVICES) {
  for (const [scheme, colours] of Object.entries(SCHEMES)) {
    const name = `launch-${d.w * d.dpr}x${d.h * d.dpr}-${scheme}.png`;
    writeFileSync(`app/public/splash/${name}`, new Resvg(svg(d, colours)).render().asPng());
    links.push(
      `    <link rel="apple-touch-startup-image" href="/splash/${name}" media="(device-width: ${d.w}px) and (device-height: ${d.h}px) and (-webkit-device-pixel-ratio: ${d.dpr}) and (orientation: portrait) and (prefers-color-scheme: ${scheme})" />`,
    );
  }
}

const START = "    <!-- launch-images:start (written by scripts/make-launch-images.mjs) -->";
const END = "    <!-- launch-images:end -->";
const html = readFileSync("app/index.html", "utf8");
const block = [START, ...links, END].join("\n");
const next = html.includes(START)
  ? html.replace(new RegExp(`${START.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}[\\s\\S]*?${END}`), block)
  : html.replace('    <script src="/theme-init.js"></script>', `${block}\n    <script src="/theme-init.js"></script>`);
writeFileSync("app/index.html", next);
console.log(`Wrote ${links.length} launch images to app/public/splash and linked them in app/index.html.`);
