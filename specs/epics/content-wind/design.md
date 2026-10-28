# content-wind — design

## The template

Content Wind is a small Nuxt app: Nuxt Content, Tailwind CSS 4 (with its
typography plugin), Nuxt Icon with the Lucide and Simple Icons sets, Nuxt
Fonts (Inter) and the colour mode. `app/` holds a navbar (the navigation
Nuxt Content generates from the pages, the author's social links, the
colour switch), two layouts (a card and full width), one catch-all page
that renders whatever page the path names with its layout and meta tags,
and the components Markdown uses (`button-link`, `markdown-block`).
`content/` is the site: a home page that is the theme's own guide, and an
about page. Nuxt Content compiles the Markdown at build time into one
collection (`content`) and serves it from a SQL database at run time — on
Vercel, an SQLite file; here, D1.

This port is upstream's `main` at `f0e56c9` (2026-10-23; the repository has
no release tags), every dependency pinned at the version its lockfile
resolves.

## How it maps to Cloudflare

| Vercel | Here |
|---|---|
| Zero-config Nuxt hosting (Nitro's Vercel preset) | Nitro's `cloudflare_module` preset: `.output/server/index.mjs` is the Worker, `.output/public` its static assets; `deployConfig: false`, the committed `wrangler.jsonc` is the config |
| Pages rendered per request | Every page prerendered by `nuxt build` (crawled from `/`) with its payload, served as Workers Static Assets with `drop-trailing-slash`; the Worker runs only for what is not a file |
| Nuxt Content's SQLite on Vercel | `content.database: { type: 'd1', bindingName: 'DB' }`: a D1 database per environment from `infra/terraform/cloudflare-d1`, its id rendered into `wrangler.jsonc` from the root's wiring document. Nuxt Content creates and fills its table from the dump the build bundles, on the first query |
| Nuxt Icon's server endpoint | Every icon the site names bundled into the client (`icon.clientBundle`); on an edge preset the server would fetch whole collections from a CDN while it renders |
| `VERCEL_URL` for the site's origin | `NUXT_SITE_URL` set by the build per environment — its `SITE_URL` in `intent.yaml`, else its workers.dev URL — baked into the pages' Open Graph image and page URLs |
| Vercel Analytics (`@vercel/analytics/nuxt`) | Not carried |
| Deploy on push | Orun applies the database and deploys `<repo>-web-{stage,prod}` on merge to `main` |
| "Deploy with Vercel" | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## The repository

docus's shape — turso-starter's without its migrations: a pnpm workspace
with `apps/web` (the site), `infra/terraform/cloudflare-d1` (the database
per environment), `tests/web` (vitest), the shared `tooling/` (TypeScript,
ESLint, the wiring renderer) and the baseline's own machinery
(`.baseline/`, the blueprints, `tooling/rebrand`, `tooling/bootstrap`,
`hooks/`, `testing/`). The site's name is one literal, `SITE_NAME` in
`apps/web/site.ts`, which `app.vue` writes into every page's title
(`<page> · <name>`) and the Open Graph site name — upstream names the site
only in its home page's heading.

The slug `content-wind` is the template's own name, and its demo content
links its repository (`Atinux/content-wind`: the source, StackBlitz, the
`nuxi init` template, the deploy buttons). So the rename engine masks those
links and the theme's comment in `content.config.ts`, and the identity's
Pascal form is `ContentWind`, which appears nowhere. The navbar's GitHub link
is the site's own repository, renamed with it; the author's X, Mastodon and
Bluesky handles are not carried.

## The build

`buildCommand` renders `wrangler.jsonc` from the environment's wiring
document, then runs `nuxt build` with `NUXT_SITE_URL` for the environment.
The build prerenders the two pages and their payloads, bundles the content
dump and the icons, and builds the server: about 0.7 MB, 0.2 MB gzipped,
far under Workers Free's 3 MiB. The smoke fetches `/` (a static asset:
Nuxt's root) and asks Nuxt Content's query route to count the pages, which
only the Worker can answer, by querying D1.

## Out of scope

- Nuxt Studio's live editing (it needs Studio's hosted service and a GitHub
  app).
- Analytics: Cloudflare's Web Analytics is the account owner's to turn on.

## The alternative rejected

A fully static site (`nuxt generate`, no Worker, no D1) would serve the two
pages the same. It was rejected for the seam the brief names: a page the
build did not prerender, the 404 and Nuxt Content's query route are the
Worker's, reading D1, exactly as docus does — so the two Nuxt Content
starters share one shape, and an owner's site can grow pages that render
on demand without a change of architecture.
