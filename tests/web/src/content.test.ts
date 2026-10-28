import { readdirSync, readFileSync, statSync } from "node:fs";
import * as path from "node:path";
import { describe, expect, it } from "vitest";

const web = path.resolve(__dirname, "../../../apps/web");
const content = path.join(web, "content");

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const full = path.join(dir, name);
    return statSync(full).isDirectory() ? files(full) : [full];
  });
}
const pages = files(content).filter((f) => f.endsWith(".md"));

// A page's route: numeric ordering prefixes dropped (`2.about` → `about`),
// `index` the folder's own route.
function route(file: string): string {
  const rel = path.relative(content, file).replace(/\.md$/, "");
  const parts = rel.split(path.sep).map((p) => p.replace(/^\d+\./, ""));
  if (parts[parts.length - 1] === "index") parts.pop();
  return "/" + parts.join("/");
}
const routes = new Set(pages.map(route));
const layouts = new Set(readdirSync(path.join(web, "app/layouts")).map((f) => f.replace(/\.vue$/, "")));
const frontMatter = (text: string) => /^---\n([\s\S]*?)\n---/.exec(text)?.[1] ?? "";

describe("the site's pages (apps/web/content)", () => {
  it("has a home page and pages beside it", () => {
    expect(routes.has("/")).toBe(true);
    expect(pages.length).toBeGreaterThan(1);
  });

  it.each(pages.map((p) => [path.relative(content, p)]))("%s has a title", (rel) => {
    const text = readFileSync(path.join(content, rel), "utf8");
    const title = /^\s*title:\s*(.+)$/m.exec(frontMatter(text))?.[1] ?? /^#\s+(.+)$/m.exec(text)?.[1];
    expect(title?.trim(), "a front-matter title or a # heading").toBeTruthy();
  });

  it.each(pages.map((p) => [path.relative(content, p)]))("%s asks for a layout that exists", (rel) => {
    const layout = /^layout:\s*(\S+)\s*$/m.exec(frontMatter(readFileSync(path.join(content, rel), "utf8")))?.[1];
    expect(layout === undefined || layouts.has(layout), `layout ${layout} in app/layouts`).toBe(true);
  });

  it("links only to pages that exist", () => {
    const missing: string[] = [];
    for (const file of pages) {
      const text = readFileSync(file, "utf8");
      const links = [
        ...text.matchAll(/\]\((\/[a-z0-9/-]*)(?:#[^)]*)?\)/g),
        ...text.matchAll(/^\s*(?:to|href):\s*(\/[a-z0-9/-]*)\s*$/gm),
      ].map((m) => m[1] ?? "");
      for (const link of links) {
        if (!routes.has(link.replace(/\/$/, "") || "/")) missing.push(`${route(file)} → ${link}`);
      }
    }
    expect(missing).toEqual([]);
  });
});
