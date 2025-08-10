module.exports = {
  docs: [
    {
      type: 'category',
      label: 'Overview',
      items: ['overview/introduction', 'overview/glossary'],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/solution-architecture',
        'architecture/medallion',
        'architecture/ai-foundry',
        'architecture/network-topology',
      ],
    },
    {
      type: 'category',
      label: 'Data',
      items: [
        'data/lineage',
        'data/quality',
        'data/privacy',
      ],
    },
    {
      type: 'category',
      label: 'APIs',
      items: [
        'api/reference',
        'api/authentication',
        'api/examples',
      ],
    },
    {
      type: 'category',
      label: 'Operations',
      items: [
        'operations/runbooks',
        'operations/disaster-recovery',
        'operations/monitoring',
      ],
    },
    {
      type: 'category',
      label: 'Security',
      items: [
        'security/rbac',
        'security/compliance',
      ],
    },
  ],
};
