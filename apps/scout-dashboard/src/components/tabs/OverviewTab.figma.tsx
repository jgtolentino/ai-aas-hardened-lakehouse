import figma from '@figma/code-connect';
import { OverviewTab } from './OverviewTab';

/**
 * Overview Tab - Main dashboard view with KPIs and charts
 * Maps to Figma Overview Dashboard component with persona-based customization
 */
figma.connect(OverviewTab, 'https://www.figma.com/design/FILE_ID/OVERVIEW_NODE_ID', {
  example: ({ persona }) => (
    <OverviewTab 
      persona={figma.enum('Persona', {
        'Executive': 'executive',
        'Manager': 'manager', 
        'Analyst': 'analyst',
        'Store Manager': 'store_manager'
      })}
    />
  ),
  props: {
    persona: figma.enum('Persona', {
      'Executive': 'executive',
      'Manager': 'manager',
      'Analyst': 'analyst', 
      'Store Manager': 'store_manager'
    })
  }
});

/**
 * Variant mapping for different dashboard layouts based on user role
 */
figma.connect(OverviewTab, 'https://www.figma.com/design/FILE_ID/EXECUTIVE_OVERVIEW_NODE_ID', {
  variant: { 'Dashboard Type': 'Executive' },
  example: () => (
    <OverviewTab persona="executive" />
  )
});

figma.connect(OverviewTab, 'https://www.figma.com/design/FILE_ID/MANAGER_OVERVIEW_NODE_ID', {
  variant: { 'Dashboard Type': 'Manager' },
  example: () => (
    <OverviewTab persona="manager" />
  )
});

figma.connect(OverviewTab, 'https://www.figma.com/design/FILE_ID/ANALYST_OVERVIEW_NODE_ID', {
  variant: { 'Dashboard Type': 'Analyst' },
  example: () => (
    <OverviewTab persona="analyst" />
  )
});