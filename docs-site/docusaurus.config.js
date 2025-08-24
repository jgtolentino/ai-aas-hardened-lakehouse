// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const lightCodeTheme = require('prism-react-renderer/themes/github');
const darkCodeTheme = require('prism-react-renderer/themes/dracula');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Scout Analytics Platform',
  tagline: 'Real-time Retail Intelligence for the Philippines',
  favicon: 'img/favicon.ico',

  // Production URL
  url: 'https://docs.scout.insightpulse.ai',
  baseUrl: '/',

  // GitHub pages deployment config (if needed)
  organizationName: 'tbwa-data-collective',
  projectName: 'scout-docs',

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  // Internationalization
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/jgtolentino/ai-aas-hardened-lakehouse/tree/main/docs-site/',
          showLastUpdateAuthor: true,
          showLastUpdateTime: true,
          // Version configuration
          versions: {
            current: {
              label: 'v5.2 (Latest)',
              path: 'v5.2',
              badge: true,
            },
          },
        },
        blog: false, // Disable blog
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
        // Google Analytics
        gtag: {
          trackingID: 'G-XXXXXXXXXX',
          anonymizeIP: true,
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      // Scout brand colors
      colorMode: {
        defaultMode: 'light',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
      
      // Announcement bar for important updates
      announcementBar: {
        id: 'v5_2_release',
        content: '🚀 Scout v5.2 is now live! Check out the <a href="/docs/intro/release-notes">release notes</a> for new features.',
        backgroundColor: '#1E3A8A',
        textColor: '#ffffff',
        isCloseable: true,
      },

      // Navigation bar
      navbar: {
        title: 'Scout Docs',
        logo: {
          alt: 'Scout Logo',
          src: 'img/scout-logo.svg',
          srcDark: 'img/scout-logo-dark.svg',
        },
        items: [
          {
            type: 'doc',
            docId: 'intro/index',
            position: 'left',
            label: '📚 Documentation',
          },
          {
            type: 'doc',
            docId: 'api/overview',
            position: 'left',
            label: '🔌 API',
          },
          {
            type: 'doc',
            docId: 'playbooks/overview',
            position: 'left',
            label: '📊 Playbooks',
          },
          {
            type: 'doc',
            docId: 'ai-agents/overview',
            position: 'left',
            label: '🤖 AI Agents',
          },
          {
            type: 'docsVersionDropdown',
            position: 'right',
            dropdownActiveClassDisabled: true,
          },
          {
            href: 'https://scout.insightpulse.ai',
            label: 'Dashboard',
            position: 'right',
          },
          {
            href: 'https://github.com/jgtolentino/ai-aas-hardened-lakehouse',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },

      // Footer configuration
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Documentation',
            items: [
              {
                label: 'Getting Started',
                to: '/docs/intro',
              },
              {
                label: 'API Reference',
                to: '/docs/api/overview',
              },
              {
                label: 'Playbooks',
                to: '/docs/playbooks/overview',
              },
            ],
          },
          {
            title: 'Platform',
            items: [
              {
                label: 'Scout Dashboard',
                href: 'https://scout.insightpulse.ai',
              },
              {
                label: 'Supabase Console',
                href: 'https://app.supabase.io',
              },
              {
                label: 'Status Page',
                href: 'https://status.insightpulse.ai',
              },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/jgtolentino/ai-aas-hardened-lakehouse',
              },
              {
                label: 'Slack',
                href: 'https://tbwa-data.slack.com/channels/scout-platform',
              },
              {
                label: 'Support',
                href: 'mailto:scout-support@insightpulse.ai',
              },
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'TBWA Data Collective',
                href: 'https://tbwa.com.ph',
              },
              {
                label: 'InsightPulse',
                href: 'https://insightpulse.ai',
              },
              {
                label: 'Privacy Policy',
                href: '/privacy',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} TBWA Data Collective. Built with ❤️ for the Philippines.`,
      },

      // Prism code highlighting
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
        additionalLanguages: ['bash', 'sql', 'typescript', 'jsx'],
      },

      // Algolia DocSearch (when configured)
      algolia: {
        appId: 'YOUR_APP_ID',
        apiKey: 'YOUR_SEARCH_API_KEY',
        indexName: 'scout_docs',
        contextualSearch: true,
        searchParameters: {},
        searchPagePath: 'search',
      },

      // Metadata for SEO
      metadata: [
        {name: 'keywords', content: 'scout, analytics, philippines, retail, sari-sari, fmcg, data'},
        {name: 'description', content: 'Comprehensive documentation for Scout Analytics Platform - Real-time retail intelligence for the Philippines'},
        {property: 'og:title', content: 'Scout Analytics Documentation'},
        {property: 'og:description', content: 'Learn how to use Scout for retail analytics in the Philippines'},
        {property: 'og:image', content: 'https://docs.scout.insightpulse.ai/img/scout-og.png'},
      ],

      // Table of contents configuration
      tableOfContents: {
        minHeadingLevel: 2,
        maxHeadingLevel: 4,
      },

      // Live code blocks (if needed)
      liveCodeBlock: {
        playgroundPosition: 'bottom',
      },

      // Mermaid diagram support
      mermaid: {
        theme: {light: 'default', dark: 'dark'},
      },

      // Custom pages paths
      customFields: {
        // Custom fields accessible in components
        supportEmail: 'scout-support@insightpulse.ai',
        dashboardUrl: 'https://scout.insightpulse.ai',
        apiBaseUrl: 'https://api.scout.insightpulse.ai',
      },
    }),

  // Plugins
  plugins: [
    // Search plugin (local search as fallback if Algolia not configured)
    [
      require.resolve('@cmfcmf/docusaurus-search-local'),
      {
        indexDocs: true,
        indexDocSidebarParentCategories: 0,
        indexBlog: false,
        indexPages: false,
        language: 'en',
        style: undefined,
        maxSearchResults: 8,
        lunr: {
          tokenizerSeparator: /[\s\-]+/,
          b: 0.75,
          k1: 1.2,
          titleBoost: 5,
          contentBoost: 1,
          parentCategoriesBoost: 2,
        },
      },
    ],
    
    // PWA support
    [
      '@docusaurus/plugin-pwa',
      {
        debug: false,
        offlineModeActivationStrategies: [
          'appInstalled',
          'standalone',
          'queryString',
        ],
        pwaHead: [
          {
            tagName: 'link',
            rel: 'icon',
            href: '/img/scout-icon.png',
          },
          {
            tagName: 'link',
            rel: 'manifest',
            href: '/manifest.json',
          },
          {
            tagName: 'meta',
            name: 'theme-color',
            content: '#1E3A8A',
          },
        ],
      },
    ],

    // Ideal image plugin for optimized images
    [
      '@docusaurus/plugin-ideal-image',
      {
        quality: 70,
        max: 1030,
        min: 640,
        steps: 2,
        disableInDev: false,
      },
    ],

    // Client redirects
    [
      '@docusaurus/plugin-client-redirects',
      {
        redirects: [
          {
            from: '/docs',
            to: '/docs/intro',
          },
          {
            from: '/api',
            to: '/docs/api/overview',
          },
        ],
      },
    ],

    // Sitemap generation
    [
      '@docusaurus/plugin-sitemap',
      {
        changefreq: 'weekly',
        priority: 0.5,
        ignorePatterns: ['/tags/**'],
        filename: 'sitemap.xml',
      },
    ],
  ],

  // Markdown features
  markdown: {
    mermaid: true,
  },

  // Scripts to load
  scripts: [
    // Add any external scripts here
  ],

  // Stylesheets to load
  stylesheets: [
    // Add any external stylesheets here
    {
      href: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap',
      type: 'text/css',
    },
  ],

  // Custom webpack configuration
  webpack: {
    jsLoader: (isServer) => ({
      loader: require.resolve('swc-loader'),
      options: {
        jsc: {
          parser: {
            syntax: 'typescript',
            tsx: true,
          },
        },
      },
    }),
  },
};

module.exports = config;
