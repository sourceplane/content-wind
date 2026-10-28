# content-wind — risks and open questions

| ID | Risk | State | Notes |
|---|---|---|---|
| CW-A | `baseline-v1` is not yet proven live | OPEN | Proven offline in Baseline CI: the offline bootstrap with the blueprint's own hooks, the stage lane's own steps in a staged job tree (the stage database id rendered, the dry run binding it), the built Worker served by `wrangler dev` over an empty local D1 — the pages and their payloads, Nuxt Content's query route answering from the table it created, the 404 |
| CW-B | Nuxt Content fills D1 on a request | ACCEPTED | The first query after a deploy recreates the table from the bundled dump (the smoke's query-route call is that query); a later build with different content does the same. Concurrent first requests may both import — Nuxt Content's own behaviour on any SQL database |
| CW-C | An icon named only at runtime | ACCEPTED | Every icon the app and content name is bundled, and the tests check the list; a name built at runtime would fall back to Nuxt Icon's CDN fetch, which is slow on a Worker |
| CW-D | The build fetches its font | ACCEPTED | Nuxt Fonts downloads Inter from Google Fonts at build time and self-hosts it, as upstream; a build with no network fails |
| CW-E | Nuxt Content's query route is public | WATCH | Upstream's own route, unauthenticated: it runs only the SELECTs its query builder writes against the site's public content and refuses anything else (a write, another table — the e2e checks both). A Nuxt Content upgrade that loosened it would be caught there |
| CW-F | stack-tectonic 0.19.0, not 0.20.0 | ACCEPTED | The job installs inside its own tree, as every sibling verified |
