import { readdirSync, readFileSync, statSync } from "node:fs";
import * as path from "node:path";
import { describe, expect, it } from "vitest";

const web = path.resolve(__dirname, "../../../apps/web");
const read = (rel: string) => readFileSync(path.join(web, rel), "utf8");

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const full = path.join(dir, name);
    return statSync(full).isDirectory() ? files(full) : [full];
  });
}

describe("the site's name (apps/web/site.ts)", () => {
  it("is written once, as a literal", () => {
    const m = /^export const SITE_NAME = (".*")$/m.exec(read("site.ts"));
    expect(m, "SITE_NAME line").not.toBeNull();
    expect(JSON.parse(m?.[1] ?? "\"\"").trim()).not.toBe("");
  });

  it("titles every page and names the site for Open Graph (app/app.vue)", () => {
    const app = read("app/app.vue");
    expect(app).toContain("import { SITE_NAME } from '../site'");
    expect(app).toMatch(/titleTemplate: \(title\?: string\) => \(route\.path === '\/' \|\| !title \|\| title === SITE_NAME \? SITE_NAME : `\$\{title\} · \$\{SITE_NAME\}`\)/);
    expect(app).toContain("ogSiteName: SITE_NAME");
  });

  it("links the navbar to the site's own repository, and to nobody else's accounts", () => {
    const config = read("app/app.config.ts");
    // The repository is the workspace's own name (the root package.json's).
    const repo = JSON.parse(readFileSync(path.join(web, "../../package.json"), "utf8")).name as string;
    expect(config).toMatch(new RegExp(`github: '[A-Za-z0-9_.-]+/${repo}',`));
    expect(config).not.toMatch(/twitter:|mastodon:|bluesky:|Atinux/);
  });
});

describe("the Workers build (apps/web/nuxt.config.ts, wrangler.template.jsonc)", () => {
  it("builds with Nitro's Cloudflare preset and prerenders the pages", () => {
    const config = read("nuxt.config.ts");
    expect(config).toContain("preset: 'cloudflare_module'");
    // The committed wrangler config is what deploys; Nitro writes none.
    expect(config).toContain("deployConfig: false");
    expect(config).toMatch(/prerender: \{\s*crawlLinks: true,\s*routes: \['\/'\],/);
    // Vercel's analytics module is not carried.
    expect(config).not.toContain("@vercel/analytics");
  });

  it("puts Nuxt Content on the D1 binding the Worker declares", () => {
    const config = read("nuxt.config.ts");
    const binding = /database: \{ type: 'd1', bindingName: '([A-Z_]+)' \}/.exec(config)?.[1];
    expect(binding).toBe("DB");
    const template = read("wrangler.template.jsonc");
    expect(template).toContain(`"binding": "${binding}"`);
    expect(template).toContain("@@wiring(cloudflare-d1/__ENV__:d1_database_id)@@");
  });

  it("deploys the Worker Nitro emits and the pages it prerenders, without trailing slashes", () => {
    const template = read("wrangler.template.jsonc");
    expect(template).toContain('"main": "./.output/server/index.mjs"');
    expect(template).toContain('"directory": "./.output/public"');
    expect(template).toContain('"html_handling": "drop-trailing-slash"');
  });

  it("bundles every icon the site names, so no render fetches an icon collection", () => {
    const config = read("nuxt.config.ts");
    const bundled = new Set([...config.matchAll(/'((?:lucide|simple-icons):[a-z0-9-]+)'/g)].map((m) => m[1]));
    const aliases = Object.fromEntries(
      [...read("app/app.config.ts").matchAll(/'([a-z-]+)': '(lucide|simple-icons)-([a-z0-9-]+)'/g)].map((m) => [m[1], `${m[2]}:${m[3]}`]),
    );
    const named = new Set<string>();
    for (const file of [...files(path.join(web, "app")), ...files(path.join(web, "content"))]) {
      if (!/\.(vue|ts|md)$/.test(file)) continue;
      const text = readFileSync(file, "utf8");
      for (const m of text.matchAll(/(?:name="|icon: )(i-(lucide|simple-icons)-([a-z0-9-]+)|(lucide|simple-icons):([a-z0-9-]+)|([a-z]+-mode))"?/g)) {
        if (m[2]) named.add(`${m[2]}:${m[3]}`);
        else if (m[4]) named.add(`${m[4]}:${m[5]}`);
        else if (m[6] && aliases[m[6]]) named.add(aliases[m[6]] as string);
      }
    }
    expect(named.size).toBeGreaterThan(5);
    expect([...named].filter((icon) => !bundled.has(icon))).toEqual([]);
  });
});
