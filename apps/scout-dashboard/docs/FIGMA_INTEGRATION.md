# Figma Code Connect Integration

## Overview

Scout Analytics Dashboard v6.0 is now integrated with the **Finebank Financial Management Dashboard UI Kit** design system through Figma Code Connect. This integration ensures design-code consistency and enables developers to access production-ready code snippets directly from Figma Dev Mode.

## Design System Integration

### 🎨 Finebank Design System
- **Figma Document**: [Finebank Financial Dashboard UI Kit](https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/Finebank---Financial-Management-Dashboard-UI-Kits--Community-)
- **Node ID**: `66-1754` (Main dashboard components)
- **Style**: Financial/Banking dashboard with clean, professional aesthetics
- **Color Palette**: Blue primary, green success, red danger, neutral grays

### 🔗 Connected Components

| Component | Figma Mapping | Code Location |
|-----------|---------------|---------------|
| **KPI Cards** | Financial metrics cards | `src/components/scout/KpiCard/` |
| **Overview Dashboard** | Main dashboard layout | `src/components/tabs/OverviewTab/` |
| **Analytics Charts** | Chart components | `src/components/charts/AnalyticsChart/` |
| **AI Recommendations** | Insights panel | `src/components/ai/RecommendationPanel/` |
| **Sidebar Navigation** | Navigation component | `src/components/layout/Sidebar/` |

## Setup Instructions

### 1. Prerequisites
```bash
# Ensure Code Connect is installed
pnpm add -D @figma/code-connect

# Verify setup
npx figma --version
```

### 2. Configuration
```bash
# Run automated setup
./scripts/setup-figma-code-connect.sh

# Or manual setup
npx figma connect init
```

### 3. Environment Variables
```bash
# Add to your .env.local
FIGMA_ACCESS_TOKEN=your_figma_personal_access_token
```

### 4. Parse and Publish
```bash
# Parse existing components
npx figma connect parse

# Validate mappings
npx figma connect validate

# Publish to Figma
npx figma connect publish
```

## Component Mapping Examples

### KPI Card Mapping
```tsx
// src/components/scout/KpiCard/index.figma.tsx
figma.connect(KpiCard, 'https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/...', {
  example: ({ title, value, changeType }) => (
    <KpiCard 
      title={figma.string('Title')}
      value={figma.string('Value')}
      change={figma.number('Change Percentage')}
      changeType={figma.enum('Trend', {
        'Positive': 'increase',
        'Negative': 'decrease'
      })}
      icon={figma.enum('Icon Type', {
        'Revenue': 'gmv',
        'Transactions': 'transactions'
      })}
    />
  )
});
```

### Chart Component Mapping
```tsx
// src/components/charts/AnalyticsChart.figma.tsx
figma.connect(AnalyticsChart, '...', {
  props: {
    type: figma.enum('Chart Type', {
      'Line': 'line',
      'Bar': 'bar',
      'Area': 'area'
    }),
    color: figma.enum('Color Theme', {
      'Primary': '#0066cc',
      'Success': '#00b894',
      'Warning': '#fdcb6e'
    })
  }
});
```

## Design Tokens Integration

### Color System
Our components now use the Finebank color palette:

```css
:root {
  --finebank-primary: #0066cc;
  --finebank-success: #00b894;
  --finebank-warning: #fdcb6e;
  --finebank-danger: #e84393;
}
```

### Typography
Financial dashboard typography optimized for data readability:

```css
.finebank-kpi-card__value {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--finebank-gray-900);
}
```

### Component Styling
Consistent styling across all components:

```css
.finebank-kpi-card {
  background: white;
  border: 1px solid var(--finebank-gray-200);
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}
```

## Benefits

### For Designers
- **Live Code Preview**: See actual production code in Figma Dev Mode
- **Prop Mapping**: Dynamic examples with real data
- **Design Consistency**: Automated sync between design and code
- **Component Status**: Real-time component implementation status

### For Developers
- **Production Code**: Copy-paste ready code snippets
- **Type Safety**: Full TypeScript support with prop mapping
- **Design Specs**: Automatic design specification extraction
- **Version Control**: Tracked changes between design and code

### For Product Teams
- **Single Source of Truth**: Unified design system
- **Faster Handoff**: Reduced design-to-development time
- **Quality Assurance**: Consistent implementation across features
- **Documentation**: Self-documenting component library

## Workflow

### Design Updates
1. Designer updates component in Figma
2. Developer receives notification of changes
3. Code Connect automatically updates mappings
4. Developer reviews and implements changes
5. Updated code is republished to Figma

### New Component Creation
1. Designer creates component in Figma
2. Developer implements React component
3. Code Connect mapping is created (`.figma.tsx`)
4. Component is published to Figma
5. Design-code link is established

## File Structure

```
src/
├── components/
│   ├── scout/
│   │   └── KpiCard/
│   │       ├── index.tsx           # Component implementation
│   │       ├── index.figma.tsx     # Code Connect mapping
│   │       └── KpiCard.stories.tsx # Storybook stories
│   ├── charts/
│   │   ├── AnalyticsChart.tsx
│   │   └── AnalyticsChart.figma.tsx
│   └── ...
├── styles/
│   └── finebank-design-system.css  # Design system styles
├── docs/
│   └── FIGMA_INTEGRATION.md        # This file
└── scripts/
    └── setup-figma-code-connect.sh # Setup automation
```

## Advanced Features

### Prop Validation
Code Connect validates props against Figma variants:

```tsx
props: {
  size: figma.enum('Size', {
    'Small': 'sm',
    'Medium': 'md', 
    'Large': 'lg'
  }),
  variant: figma.enum('Variant', {
    'Primary': 'primary',
    'Secondary': 'secondary'
  })
}
```

### Instance Mapping
Complex components with child instances:

```tsx
example: () => (
  <Dashboard>
    {figma.children('KPI Cards')}
    <Chart data={figma.instance('Chart Data')} />
    {figma.children('Action Buttons')}
  </Dashboard>
)
```

### Conditional Rendering
Dynamic examples based on Figma properties:

```tsx
example: ({ showTrend, hasIcon }) => (
  <KpiCard
    trend={figma.boolean('Show Trend') ? trendData : undefined}
    icon={figma.boolean('Has Icon') ? iconComponent : undefined}
  />
)
```

## Troubleshooting

### Common Issues

**Components not appearing in Figma**
- Verify `FIGMA_ACCESS_TOKEN` is set correctly
- Check document ID matches in `figma.config.json`
- Run `npx figma connect validate` for errors

**Prop mapping errors**
- Ensure Figma variant names match code enum values
- Check for typos in property names
- Validate component exports are correct

**Build failures**
- Update `@figma/code-connect` to latest version
- Check TypeScript errors in `.figma.tsx` files
- Verify all imports are correct

### Debug Commands
```bash
# Validate all connections
npx figma connect validate

# Check connection status
npx figma connect status

# Debug specific component
npx figma connect parse --component KpiCard

# Dry run publish
npx figma connect publish --dry-run
```

## Next Steps

1. **Expand Component Coverage**: Add Code Connect to remaining components
2. **Design System Evolution**: Contribute back to Finebank design system
3. **Automated Testing**: Integrate visual regression testing
4. **CI/CD Integration**: Automate Code Connect publishing in deployment pipeline
5. **Team Training**: Onboard design and development teams on new workflow

## Resources

- [Figma Code Connect Documentation](https://www.figma.com/code-connect-docs/)
- [Finebank Design System](https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/)
- [Scout Dashboard Components](./src/components/)
- [Setup Script](./scripts/setup-figma-code-connect.sh)