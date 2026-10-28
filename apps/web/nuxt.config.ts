import tailwindcss from '@tailwindcss/vite'

// Content Wind (atinux/content-wind) as upstream ships it — Nuxt Content,
// Tailwind CSS, Nuxt Icon, Nuxt Fonts and the colour mode — with Vercel's
// zero-config Nuxt hosting replaced by Nitro's Cloudflare Workers preset.
//
// `nuxt build` prerenders every page (crawling the links from `/`) into
// .output/public, the static assets, and emits .output/server/index.mjs, the
// Worker, for what must run per request: any page that was not prerendered
// and Nuxt Content's queries. Those read a Cloudflare D1 database, bound as
// DB, which Nuxt Content creates its tables in and fills from the dump the
// build bundles, on the first query after a deploy — there are no
// migrations. The committed wrangler.jsonc is the deployable config, so
// Nitro writes no wrangler.json of its own (deployConfig: false).
//
// The site's name is SITE_NAME (site.ts), which app.vue writes into every
// page's title and Open Graph site name. Its public origin is NUXT_SITE_URL,
// which the deploy sets per environment and the build bakes into the
// prerendered pages: Open Graph wants an absolute image and page URL.
export default defineNuxtConfig({
  modules: [
    '@nuxt/content',
    '@nuxt/icon',
    '@nuxt/eslint',
    '@nuxt/fonts',
    '@nuxtjs/color-mode',
  ],

  runtimeConfig: {
    public: { siteUrl: process.env.NUXT_SITE_URL || '' },
  },

  css: ['assets/css/main.css'],
  colorMode: { classSuffix: '' },

  fonts: {
    families: [{ name: 'Inter', weights: [400, 500, 600], global: true }],
  },

  content: {
    database: { type: 'd1', bindingName: 'DB' },
    build: {
      markdown: {
        highlight: {
          // See the available themes on https://github.com/shikijs/shiki/blob/main/docs/themes.md#all-theme
          theme: {
            dark: 'github-dark',
            default: 'github-light',
          },
        },
      },
    },
    experimental: { sqliteConnector: 'native' },
  },

  // Every icon the site names, bundled into the client. On an edge preset
  // Nuxt Icon's server would otherwise fetch whole icon collections from a CDN
  // while it renders; a name only known at runtime still falls back to that.
  icon: {
    clientBundle: {
      scan: { globInclude: ['app/**/*.vue', 'content/**/*.md'] },
      icons: [
        'lucide:moon',
        'lucide:sun',
        'lucide:music',
        'lucide:star',
        'simple-icons:x',
        'simple-icons:github',
        'simple-icons:mastodon',
        'simple-icons:bluesky',
        'simple-icons:stackblitz',
      ],
    },
  },

  nitro: {
    preset: 'cloudflare_module',
    cloudflare: {
      deployConfig: false,
      nodeCompat: true,
    },
    prerender: {
      crawlLinks: true,
      routes: ['/'],
    },
  },

  future: {
    compatibilityVersion: 4,
  },
  compatibilityDate: '2025-02-19',

  vite: { plugins: [tailwindcss()] },
})
