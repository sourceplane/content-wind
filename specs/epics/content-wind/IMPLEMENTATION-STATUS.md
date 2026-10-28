# content-wind — implementation status

| Milestone | State | Landed |
|---|---|---|
| CW0 — the spec | ✅ | the repository's first commit |
| CW1 — Content Wind on Workers and D1 | ✅ | CW-2 |
| CW2 — a baseline | planned | CW-3 |

## Departures from the upstream template

Everything not listed here is Content Wind as it is at `f0e56c9`: the app,
the content, the images, the LICENSE.

| # | What | Why |
|---|---|---|
| 1 | The template lives in `apps/web` of a pnpm workspace; its README is replaced by `apps/web/README.md`, its `.gitignore` merged into the root's; `.agents/`, `.vscode/` and `renovate.json` are not carried | The repository's shape |
| 2 | Dependencies pinned at the versions upstream's lockfile resolves (`^` dropped) | Reproducible builds |
| 3 | `@vercel/analytics` and its module dropped | Vercel's own analytics |
| 4 | `nuxt.config.ts`: `content.database` on the D1 binding `DB` | Nuxt Content's SQLite file on Vercel becomes D1 |
| 5 | `nuxt.config.ts`: Nitro's `cloudflare_module` preset, `deployConfig: false`, `nodeCompat: true`, every page prerendered (`crawlLinks`, from `/`) | Vercel's Nuxt hosting becomes a Worker with Static Assets; the committed `wrangler.jsonc` is the config |
| 6 | `nuxt.config.ts`: every icon the site names in `icon.clientBundle` | On an edge preset Nuxt Icon's server fetches whole collections from a CDN while it renders (risk CW-C) |
| 7 | `site.ts` (`SITE_NAME`); `app.vue` writes it into every page's title (`<page> · <name>`, the home page the name alone, whatever its heading says) and `og:site_name` | One rename seam; upstream names the site only in its home page's heading |
| 8 | `NUXT_SITE_URL` set by the build per environment, read as `runtimeConfig.public.siteUrl`; `app.vue` makes `og:image` absolute and adds `og:url` | Open Graph wants absolute URLs; upstream gave a relative image |
| 9 | `app.config.ts`: `socials.github` is the site's own repository; the author's X, Mastodon and Bluesky handles removed; the `socials` object typed with every key the navbar reads | A product must not link to the template author's accounts; the navbar shows a link only when it is set |
| 10 | `pages/[...slug].vue` imports `LayoutKey` from `#app` | Nuxt 4.6 declares it on `nuxt/app`; upstream's `#build/types/layouts` import no longer type-checks (it is type-only, so upstream runs) |
| 11 | Scripts: `preview` (wrangler dev), `postinstall` (`nuxt prepare`), `typecheck` (vue-tsc on the app project), `lint` after `nuxt prepare` | Upstream has no type-check; its lint reads the config `nuxt prepare` writes |
| 12 | `wrangler.template.jsonc` (with `html_handling: drop-trailing-slash`), `wiring.fixture.json`, `wrangler.jsonc` (the render), `component.yaml`, `.env.example`, `tsconfig.json` (project references) | The Workers runtime and the deploy contract |
