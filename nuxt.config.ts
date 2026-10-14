// https://nuxt.com/docs/api/configuration/nuxt-config
const baseURL = process.env.NUXT_APP_BASE_URL || '/'
const siteUrl = 'https://mponzo.github.io/MacCleaner'
const title = 'MacCleaner — open-source Mac cleaner, zero telemetry'
const description =
  'Free open-source Mac cleaner for macOS 14+. Smart Care, deep uninstall, Space Explorer, Schedule, System Monitor, Developer Cleanup (Simulator, Docker, AI), 10 languages. Fully local, zero telemetry, MIT.'

export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  ssr: true,
  devtools: { enabled: false },
  css: ['~/assets/css/main.css'],
  app: {
    baseURL,
    head: {
      htmlAttrs: { lang: 'en' },
      title,
      titleTemplate: '%s',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'description', content: description },
        {
          name: 'keywords',
          content:
            'Mac cleaner, macOS cleaner, Smart Care, uninstall Mac apps, free disk space, open source, zero telemetry, Homebrew cask, Time Machine snapshots, developer cleanup',
        },
        { name: 'author', content: 'MacCleaner contributors' },
        { name: 'robots', content: 'index, follow, max-image-preview:large' },
        { name: 'theme-color', content: '#0A1A33' },
        { name: 'application-name', content: 'MacCleaner' },
        { name: 'apple-mobile-web-app-title', content: 'MacCleaner' },
        { property: 'og:site_name', content: 'MacCleaner' },
        { property: 'og:title', content: title },
        { property: 'og:description', content: description },
        { property: 'og:type', content: 'website' },
        { property: 'og:url', content: `${siteUrl}/` },
        { property: 'og:locale', content: 'en_US' },
        { property: 'og:image', content: `${siteUrl}/icon.png` },
        { property: 'og:image:type', content: 'image/png' },
        { property: 'og:image:alt', content: 'MacCleaner app icon' },
        { name: 'twitter:card', content: 'summary_large_image' },
        { name: 'twitter:title', content: title },
        { name: 'twitter:description', content: description },
        { name: 'twitter:image', content: `${siteUrl}/icon.png` },
      ],
      link: [
        { rel: 'canonical', href: `${siteUrl}/` },
        { rel: 'icon', type: 'image/png', href: `${baseURL}icon.png` },
        { rel: 'apple-touch-icon', href: `${baseURL}icon.png` },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
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
