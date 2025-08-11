module.exports = {
  title: 'AI-AAS Hardened Lakehouse',
  tagline: 'Production-ready data lakehouse with AI/ML capabilities and enterprise security',
  url: 'https://jgtolentino.github.io',
  baseUrl: '/ai-aas-hardened-lakehouse/',
  favicon: 'img/favicon.ico',
  organizationName: 'jgtolentino',
  projectName: 'ai-aas-hardened-lakehouse',
  deploymentBranch: 'gh-pages',
  trailingSlash: false,
  
  themeConfig: {
    navbar: {
      title: 'Lakehouse Docs',
      logo: {
        alt: 'AI-AAS Lakehouse',
        src: 'img/logo.svg',
      },
      items: [
        {to: '/docs/architecture/overview', label: 'Architecture', position: 'left'},
        {to: '/docs/tutorials/quickstart', label: 'Tutorials', position: 'left'},
        {to: '/docs/api-reference/sql-interfaces', label: 'API Reference', position: 'left'},
        {to: '/docs/security/hardening-guide', label: 'Security', position: 'left'},
        {to: '/docs/operations/monitoring', label: 'Operations', position: 'left'},
        {href: 'https://github.com/jgtolentino/ai-aas-hardened-lakehouse', label: 'GitHub', position: 'right'},
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
              to: '/docs/tutorials/quickstart',
            },
            {
              label: 'Architecture',
              to: '/docs/architecture/overview',
            },
            {
              label: 'Security Guide',
              to: '/docs/security/hardening-guide',
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
              label: 'Issues',
              href: 'https://github.com/jgtolentino/ai-aas-hardened-lakehouse/issues',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'Blog',
              to: '/blog',
            },
            {
              label: 'Changelog',
              href: 'https://github.com/jgtolentino/ai-aas-hardened-lakehouse/releases',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} AI-AAS Hardened Lakehouse. Built with Docusaurus.`,
    },
    prism: {
      theme: require('prism-react-renderer/themes/github'),
      darkTheme: require('prism-react-renderer/themes/dracula'),
      additionalLanguages: ['sql', 'bash', 'yaml', 'json', 'dockerfile', 'terraform', 'python', 'javascript', 'typescript'],
    },
    mermaid: {
      theme: {light: 'default', dark: 'dark'},
    },
    algolia: {
      appId: 'YOUR_APP_ID',
      apiKey: 'YOUR_SEARCH_API_KEY',
      indexName: 'lakehouse-docs',
      contextualSearch: true,
    },
    colorMode: {
      defaultMode: 'light',
      disableSwitch: false,
      respectPrefersColorScheme: true,
    },
  },
  
  presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/jgtolentino/ai-aas-hardened-lakehouse/edit/main/docs-site/',
          remarkPlugins: [require('remark-math')],
          rehypePlugins: [require('rehype-katex')],
          showLastUpdateAuthor: true,
          showLastUpdateTime: true,
        },
        blog: {
          showReadingTime: true,
          editUrl: 'https://github.com/jgtolentino/ai-aas-hardened-lakehouse/edit/main/docs-site/',
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      },
    ],
  ],
  
  themes: ['@docusaurus/theme-mermaid'],
  markdown: {mermaid: true},
};
