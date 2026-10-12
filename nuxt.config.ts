// https://nuxt.com/docs/api/configuration/nuxt-config
const baseURL = process.env.NUXT_APP_BASE_URL || '/'

export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  ssr: true,
  devtools: { enabled: false },
  css: ['~/assets/css/main.css'],
  app: {
    baseURL,
    head: {
      htmlAttrs: { lang: 'en' },
      title: 'MacCleaner — local cleanup, zero telemetry',
      meta: [
        {
          name: 'description',
          content:
            'Open-source Mac cleaner: Smart Care, uninstall, performance, and maintenance. Zero telemetry, zero accounts, fully local.',
        },
        { name: 'theme-color', content: '#0A1A33' },
        { property: 'og:title', content: 'MacCleaner' },
        {
          property: 'og:description',
          content: 'Reclaim space on your Mac. Open source. Zero telemetry.',
        },
        { property: 'og:type', content: 'website' },
      ],
      link: [
        { rel: 'icon', type: 'image/png', href: `${baseURL}icon.png` },
        { rel: 'apple-touch-icon', href: `${baseURL}icon.png` },
        {
          rel: 'preconnect',
          href: 'https://fonts.googleapis.com',
        },
        {
          rel: 'preconnect',
          href: 'https://fonts.gstatic.com',
          crossorigin: '',
        },
        {
          rel: 'stylesheet',
          href: 'https://fonts.googleapis.com/css2?family=Figtree:wght@400;500;600;700&family=Syne:wght@600;700;800&display=swap',
        },
      ],
    },
  },
  nitro: {
    preset: 'static',
  },
})
