# apps/web — the site

A personal website written in Markdown: [Content Wind](https://github.com/Atinux/content-wind)
(MIT) — Nuxt Content, Tailwind CSS, Nuxt Icon, Nuxt Fonts and the colour
mode — running on Cloudflare Workers + Static Assets with Nuxt Content's
queries on Cloudflare D1:

- `nuxt.config.ts` puts Nuxt Content's database on the `DB` binding
  (`type: 'd1'`), bundles every icon the site names, and builds with Nitro's
  `cloudflare_module` preset — the Worker in `.output/server/index.mjs`,
  every page prerendered (crawled from `/`) into `.output/public`
- `content/` is the site: `1.index.md` the home page, a Markdown file per
  page; `app/` is Content Wind's navbar, layouts, catch-all page and the
  components Markdown uses
- Nuxt Content creates and fills its tables in D1 from the dump the build
  bundles, on the first query after a deploy — there are no migrations
- the pages and their payloads are static assets; a page the build did not
  prerender, the 404 and Nuxt Content's query route
  (`/__nuxt_content/content/query`) are answered by the Worker from D1

The site's name is in `site.ts`; the navbar's links and the cover image are
in `app/app.config.ts`.

```bash
pnpm run wire:fixture   # wrangler.jsonc from the template, placeholder database ids
pnpm dev                # nuxt dev on http://localhost:3000, the content in a local SQLite file
pnpm build              # nuxt build → .output/ (set NUXT_SITE_URL for the Open Graph URLs)
pnpm preview            # wrangler dev over the built Worker, a local D1 behind DB
```
