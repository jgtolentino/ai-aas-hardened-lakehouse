import figma from '@figma/code-connect';
import { Sidebar } from './Sidebar';

/**
 * Sidebar Navigation - Financial dashboard navigation
 * Maps to Figma Finebank sidebar component with financial navigation structure
 */
figma.connect(Sidebar, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Finebank---Financial-Management-Dashboard-UI-Kits--Community-?node-id=66-1754', {
  example: ({ isCollapsed, activeTab }) => (
    <Sidebar 
      isCollapsed={figma.boolean('Collapsed State')}
      activeTab={figma.enum('Active Tab', {
        'Overview': 'overview',
        'Analytics': 'analytics', 
        'Geography': 'geography',
        'Consumers': 'consumers',
        'Mix': 'mix',
        'AI': 'ai',
        'Competitive': 'competitive'
      })}
      userRole={figma.enum('User Role', {
        'Executive': 'executive',
        'Manager': 'manager',
        'Analyst': 'analyst',
        'Store Manager': 'store_manager'
      })}
      organizationLogo={figma.instance('Logo')}
      showBadges={figma.boolean('Show Notifications')}
    />
  ),
  props: {
    isCollapsed: figma.boolean('Collapsed State'),
    activeTab: figma.enum('Active Tab', {
      'Overview': 'overview',
      'Analytics': 'analytics',
      'Geography': 'geography', 
      'Consumers': 'consumers',
      'Mix': 'mix',
      'AI': 'ai',
      'Competitive': 'competitive'
    }),
    userRole: figma.enum('User Role', {
      'Executive': 'executive',
      'Manager': 'manager',
      'Analyst': 'analyst',
      'Store Manager': 'store_manager'
    })
  }
});

/**
 * Navigation Item mapping
 */
figma.connect(Sidebar, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Finebank---Financial-Management-Dashboard-UI-Kits--Community-?node-id=66-1754', {
  variant: { 'Component': 'Navigation Item' },
  example: () => (
    <div className="finebank-nav__item">
      {figma.instance('Icon')}
      <span>{figma.string('Label')}</span>
      {figma.boolean('Show Badge') && (
        <span className="finebank-nav__badge">
          {figma.string('Badge Text')}
        </span>
      )}
    </div>
  )
});