module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'style',
        'refactor',
        'perf',
        'test',
        'chore',
        'revert',
        'build',
        'ci',
        'security',
        'deps'
      ]
    ],
    'scope-enum': [
      2,
      'always',
      [
        'core',
        'agents',
        'mcp',
        'pulser',
        'bruno',
        'scout',
        'docs',
        'ci',
        'deps',
        'security',
        'infra',
        'superclaude'
      ]
    ]
  }
};