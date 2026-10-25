// Regenerates the app icons in public/icons/ (PWA, iPhone home screen, favicon).
// Needs Playwright with Chromium: `node scripts/make-icons.cjs`. The icons are committed,
// so this only has to run again if the design changes.
const { chromium } = require("playwright");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");

const root = join(__dirname, "..");
const font = readFileSync(join(root, "src/ui/fonts/koma.woff2")).toString("base64");
const OUTLINE =
  "M50 3 L78.5 13 Q81 14 81.4 16.5 L90.6 94.5 Q90.8 97 88.3 97 L11.7 97 Q9.2 97 9.4 94.5 L18.6 16.5 Q19 14 21.5 13 Z";

/** `pieceSize`: share of the icon taken by the piece (maskable icons keep it inside the safe zone). */
function page(pieceSize) {
  const inset = (1 - pieceSize) / 2;
  return `<!doctype html><html><head><style>
  @font-face { font-family: Koma; src: url(data:font/woff2;base64,${font}); font-weight: 700; }
  html, body { margin: 0; width: 100%; height: 100%; }
  body { background: radial-gradient(circle at 35% 30%, #a3461b, #6b2410 70%, #4a170a); }
  svg { position: absolute; left: ${inset * 100}%; top: ${inset * 100}%; width: ${pieceSize * 100}%; height: ${pieceSize * 100}%; overflow: visible; }
  text { font-family: Koma; font-weight: 700; fill: #1d1408; }
  </style></head><body>
  <svg viewBox="0 0 100 100">
    <defs>
      <linearGradient id="w" x1="0" y1="0" x2="0.9" y2="1"><stop offset="0" stop-color="#f8e2b0"/><stop offset="0.55" stop-color="#eecb86"/><stop offset="1" stop-color="#ddb068"/></linearGradient>
      <filter id="s" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="2" stdDeviation="2.5" flood-opacity="0.45"/></filter>
    </defs>
    <path d="${OUTLINE}" fill="#7a5225" transform="translate(1.6 2.2)" filter="url(#s)"/>
    <path d="${OUTLINE}" fill="url(#w)" stroke="#9a6f36" stroke-width="1.2"/>
    <text x="50" y="50" font-size="33" text-anchor="middle">王</text>
    <text x="50" y="86" font-size="33" text-anchor="middle">将</text>
  </svg></body></html>`;
}

const ICONS = [
  { file: "icon-192.png", size: 192, piece: 0.78 },
  { file: "icon-512.png", size: 512, piece: 0.78 },
  { file: "icon-maskable-512.png", size: 512, piece: 0.62 },
  { file: "apple-touch-icon.png", size: 180, piece: 0.74 },
  { file: "favicon-64.png", size: 64, piece: 0.9 },
];

(async () => {
  const browser = await chromium.launch();
  for (const icon of ICONS) {
    const tab = await browser.newPage({ viewport: { width: icon.size, height: icon.size } });
    await tab.setContent(page(icon.piece));
    await tab.evaluate(() => document.fonts.ready);
    await tab.screenshot({ path: join(root, "public/icons", icon.file) });
    await tab.close();
  }
  await browser.close();
})();
