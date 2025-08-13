const {themes} = require('prism-react-renderer');
const lightCodeTheme = themes.github;
const darkCodeTheme = themes.dracula;

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Scout Analytics Platform',
  tagline: 'Enterprise Data Platform for Philippine Retail Intelligence',
  favicon: 'img/favicon.ico',

  url: 'https://docs.scout-analytics.ph',
  baseUrl: '/',

  organizationName: 'scout-analytics',
  projectName: 'scout-docs',

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

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
          sidebarPath: './sidebars.ts',
          editUrl:
            'https://github.com/jgtolentino/ai-aas-hardened-lakehouse/tree/main/docs-site/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      navbar: {
        title: 'Scout Docs',
        logo: {
          alt: 'Scout Analytics Logo',
          src: 'img/logo.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docs',
            position: 'left',
            label: 'Documentation',
          },
          {
            href: 'https://github.com/jgtolentino/ai-aas-hardened-lakehouse',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
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
                label: 'Architecture',
                to: '/docs/architecture/overview',
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
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Scout Analytics Platform. Built with Docusaurus.`,
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
      },
    }),
};

module.exports = config;