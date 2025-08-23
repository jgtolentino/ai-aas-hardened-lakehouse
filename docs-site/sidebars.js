module.exports = {
  tutorialSidebar: [
    {
      type: 'doc',
      id: 'intro',
      label: '🏠 Introduction',
    },
    {
      type: 'category',
      label: '🏛️ Architecture',
      collapsed: false,
      items: [
        'architecture/overview',
      ],
    },
    {
      type: 'category',
      label: '🚀 Tutorials & Guides',
      collapsed: false,
      items: [
        'tutorials/quickstart',
      ],
    },
    {
      type: 'category',
      label: '🤖 Suqi Chat AI',
      collapsed: false,
      items: [
        'features/suqi-chat',
        'api-reference/suqi-chat-api',
      ],
    },
    {
      type: 'category',
      label: '🔒 Security',
      collapsed: false,
      items: [
        'security/hardening-guide',
      ],
    },
    {
      type: 'category',
      label: '📚 API Reference',
      collapsed: false,
      items: [
        'api-reference/sql-interfaces',
      ],
    },
    {
      type: 'category',
      label: '🔧 Implementation',
      collapsed: true,
      items: [
        'implementation/deployment',
      ],
    },
    {
      type: 'category',
      label: '⚙️ Operations',
      collapsed: true,
      items: [
        'operations/monitoring',
      ],
    },
  ],
};
