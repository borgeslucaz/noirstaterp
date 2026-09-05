import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const distDirectory = path.resolve(scriptDirectory, "../../dist");
const htmlPath = path.join(distDirectory, "index.html");

let html = await readFile(htmlPath, "utf8");

// A single-file NUI avoids the Enhanced client rejecting separately served
// JavaScript and CSS assets. Font paths become relative to dist/index.html.
const stylesheetPattern = /<link\s+rel="stylesheet"[^>]*href="([^"]+)"[^>]*>/g;
for (const match of [...html.matchAll(stylesheetPattern)]) {
  const assetPath = path.resolve(distDirectory, match[1]);
  const css = (await readFile(assetPath, "utf8"))
    .replaceAll("../fonts/", "./fonts/")
    .replaceAll("</style", "<\\/style");
  html = html.replace(match[0], () => `<style>${css}</style>`);
}

html = html.replace(/<link\s+rel="modulepreload"[^>]*>\s*/g, "");
html = html.replace(/<link\s+rel="icon"[^>]*>\s*/g, "");

const scriptPattern = /<script\s+type="module"[^>]*src="([^"]+)"[^>]*><\/script>/g;
for (const match of [...html.matchAll(scriptPattern)]) {
  const assetPath = path.resolve(distDirectory, match[1]);
  const javascript = (await readFile(assetPath, "utf8")).replaceAll("</script", "<\\/script");
  html = html.replace(match[0], () => `<script type="module">${javascript}</script>`);
}

await writeFile(htmlPath, html);
console.log("Inlined JavaScript and CSS into ../dist/index.html");
