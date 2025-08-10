module.exports = {
  title: 'Scout Analytics Platform',
  tagline: 'Enterprise Data Platform for Philippine Retail',
  url: 'https://docs.scout.analytics',
  baseUrl: '/',
  favicon: 'img/favicon.ico',
  organizationName: 'scout-analytics',
  projectName: 'docs',
  
  themeConfig: {
    navbar: {
      title: 'Scout Docs',
      items: [
        {to: '/docs/architecture', label: 'Architecture', position: 'left'},
        {to: '/docs/api', label: 'API', position: 'left'},
        {to: '/docs/operations', label: 'Operations', position: 'left'},
        {href: 'https://github.com/scout-analytics', label: 'GitHub', position: 'right'},
      ],
    },
    prism: {
      theme: require('prism-react-renderer/themes/github'),
      additionalLanguages: ['sql', 'bash', 'yaml'],
    },
    mermaid: {
      theme: {light: 'default', dark: 'dark'},
    },
  },
  
  presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/scout-analytics/docs/edit/main/',
          remarkPlugins: [require('remark-math')],
          rehypePlugins: [require('rehype-katex')],
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
