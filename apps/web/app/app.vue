<script setup lang="ts">
import { SITE_NAME } from '../site'

const { cover } = useAppConfig()
const { siteUrl } = useRuntimeConfig().public
const route = useRoute()
// Open Graph takes absolute URLs: on the site's origin when the build had one
// (NUXT_SITE_URL, set per environment by the deploy), relative otherwise.
const absolute = (path: string) => (siteUrl ? new URL(path, siteUrl).href : path)

// Every page is titled for the site: "<page> · <name>", and the home page —
// whatever its own heading says — the name alone.
useHead({
  titleTemplate: (title?: string) => (route.path === '/' || !title || title === SITE_NAME ? SITE_NAME : `${title} · ${SITE_NAME}`),
})

useSeoMeta({
  ogSiteName: SITE_NAME,
  ogImage: absolute(cover),
  ogUrl: () => absolute(route.path),
  twitterCard: 'summary_large_image',
})
</script>

<template>
  <div class="pb-16 sm:pt-8 sm:pb-24">
    <Html lang="en" />
    <AppNavbar />
    <NuxtPage />
  </div>
</template>
