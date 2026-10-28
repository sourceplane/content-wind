export default defineAppConfig({
  cover: '/cover.jpg',
  // The navbar's links: each one shows only when it is set. GitHub is the
  // site's own source; add the site's X, Mastodon or Bluesky handle here.
  socials: {
    github: 'sourceplane/content-wind',
  } as { twitter?: string, x?: string, github?: string, mastodon?: string, bluesky?: string },
  icon: {
    aliases: {
      'dark-mode': 'lucide-moon',
      'light-mode': 'lucide-sun',
    },
  },
})
