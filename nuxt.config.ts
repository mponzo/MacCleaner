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
      htmlAttrs: { lang: 'it' },
      title: 'MacCleaner — pulizia locale, zero telemetria',
      meta: [
        {
          name: 'description',
          content:
            'Pulitore open-source per Mac: Smart Care, disinstallazione e manutenzione. Zero telemetria, zero account, tutto in locale.',
        },
        { name: 'theme-color', content: '#0A1A33' },
        { property: 'og:title', content: 'MacCleaner' },
        {
          property: 'og:description',
          content: 'Riprendi spazio sul Mac. Open source. Zero telemetria.',
        },
        { property: 'og:type', content: 'website' },
      ],
      link: [
        { rel: 'icon', type: 'image/svg+xml', href: `${baseURL}mark.svg` },
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
