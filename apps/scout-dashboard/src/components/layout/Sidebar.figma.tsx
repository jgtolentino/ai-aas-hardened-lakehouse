import figma from '@figma/code-connect';
import { Sidebar } from './Sidebar';

/**
 * Sidebar Navigation Component
 * Maps to Figma's sidebar navigation with all menu items and states
 */
figma.connect(Sidebar, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Scout-Dashboard', {
  example: ({ activeItem, collapsed, theme }) => (
    <Sidebar 
      activeItem={figma.enum('Active Item', {
        'Overview': 'overview',
        'AI Recommendations': 'ai',
        'Analytics': 'analytics',
        'Consumers': 'consumers',
        'Geography': 'geography',
        'Competitive': 'competitive',
        'Mix': 'mix',
        'Reports': 'reports',
        'Finebank': 'finebank'
      })}
      collapsed={figma.boolean('Collapsed', false)}
      theme={figma.enum('Theme', {
        'Light': 'light',
        'Dark': 'dark'
      })}
      userRole={figma.enum('User Role', {
        'Executive': 'executive',
        'Analyst': 'analyst',
        'Viewer': 'viewer'
      })}
    />
  ),
  props: {
    activeItem: figma.string('Active Item'),
    collapsed: figma.boolean('Collapsed'),
    theme: figma.enum('Theme', {
      'Light': 'light',
      'Dark': 'dark'
    }),
    userRole: figma.enum('User Role', {
      'Executive': 'executive',
      'Analyst': 'analyst',
      'Viewer': 'viewer'
    })
  },
  imports: [
    "import { Sidebar } from '@/components/layout/Sidebar';"
  ]
});
