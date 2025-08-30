# Scout Dashboard - Figma Code Connect Integration

## Overview
This document outlines the Figma Code Connect integration for the Scout Dashboard, enabling seamless design-to-code workflow between Figma designs and React components.

## 🎨 Figma Code Connect Setup

### Prerequisites
- Node.js 18+ and npm/pnpm
- Figma account with access to the design file
- Figma CLI installed globally

### Installation

```bash
# Install dependencies
npm install

# Install Figma CLI globally
npm install -g @figma/code-connect

# Setup Code Connect
npm run figma:setup
```

## 📁 Project Structure

```
scout-dashboard/
├── src/
│   ├── components/
│   │   ├── layout/
│   │   │   ├── Sidebar.tsx
│   │   │   ├── Sidebar.figma.tsx    # Code Connect mapping
│   │   │   └── Topbar.tsx
│   │   ├── charts/
│   │   │   ├── AnalyticsChart.tsx
│   │   │   └── AnalyticsChart.figma.tsx
│   │   ├── ai/
│   │   │   ├── RecommendationPanel.tsx
│   │   │   └── RecommendationPanel.figma.tsx
│   │   └── scout/
│   │       └── KpiCard/
│   │           ├── index.tsx
│   │           └── index.figma.tsx
│   └── app/
│       └── (routes)/
├── figma.config.json              # Figma configuration
├── code-connect.config.json       # Code Connect mappings
└── deploy-dashboard.sh            # Deployment script
```

## 🔗 Component Mappings

### Dashboard Components

| Component | Figma Node | File Path |
|-----------|------------|-----------|
| Sidebar | `66-1754` | `src/components/layout/Sidebar.tsx` |
| KpiCard | `66-1754` | `src/components/scout/KpiCard/index.tsx` |
| AnalyticsChart | `66-1770` | `src/components/charts/AnalyticsChart.tsx` |
| RecommendationPanel | `66-1800` | `src/components/ai/RecommendationPanel.tsx` |
| OverviewTab | `66-1820` | `src/components/tabs/OverviewTab.tsx` |

## 🚀 Commands

### Development
```bash
# Start development server
npm run dev

# Build for production
npm run build

# Run tests
npm test
```

### Figma Code Connect
```bash
# Parse Code Connect files
npm run figma:parse

# Validate connections
npm run figma:validate

# Publish to Figma (dry run)
npm run figma:publish:dry

# Publish to Figma
npm run figma:publish
```

### Deployment
```bash
# Full deployment pipeline
./deploy-dashboard.sh

# Deploy to Vercel
vercel --prod

# Sync with Supabase
supabase db push
```

## 📝 Creating Code Connect Files

### Basic Component Example

```tsx
// ComponentName.figma.tsx
import figma from '@figma/code-connect';
import { ComponentName } from './ComponentName';

figma.connect(ComponentName, 'FIGMA_URL_HERE', {
  example: ({ prop1, prop2 }) => (
    <ComponentName 
      prop1={figma.string('Prop 1 Name')}
      prop2={figma.boolean('Prop 2 Name', false)}
    />
  ),
  props: {
    prop1: figma.string('Prop 1 Name'),
    prop2: figma.boolean('Prop 2 Name')
  }
});
```

### Advanced Mapping with Enums

```tsx
figma.connect(KpiCard, 'FIGMA_URL', {
  example: ({ state, icon }) => (
    <KpiCard
      state={figma.enum('State', {
        'Ready': 'ready',
        'Loading': 'loading',
        'Error': 'error'
      })}
      icon={figma.enum('Icon', {
        'Revenue': 'gmv',
        'Transactions': 'transactions'
      })}
    />
  )
});
```

## 🎯 Design Tokens

The dashboard uses Figma design tokens for consistent styling:

### Colors
- Primary: `#3B82F6` (Blue)
- Success: `#10B981` (Green)
- Warning: `#F59E0B` (Amber)
- Error: `#EF4444` (Red)
- Neutral: Gray scale

### Typography
- Font: Inter
- Headings: 24px, 20px, 18px, 16px
- Body: 14px, 12px

### Spacing
- Base unit: 4px
- Common spacings: 8px, 16px, 24px, 32px, 48px

## 🔄 Workflow

1. **Design in Figma**
   - Create/update components in Figma
   - Use consistent naming conventions
   - Apply variants and properties

2. **Map in Code**
   - Create `.figma.tsx` files for components
   - Define props and examples
   - Map Figma properties to code props

3. **Parse & Validate**
   - Run `npm run figma:parse`
   - Validate with `npm run figma:validate`
   - Fix any mapping issues

4. **Publish**
   - Test locally with `npm run dev`
   - Publish to Figma with `npm run figma:publish`
   - Deploy to production

## 🐛 Troubleshooting

### Common Issues

1. **Figma CLI not found**
   ```bash
   npm install -g @figma/code-connect
   ```

2. **Parse errors**
   - Check syntax in `.figma.tsx` files
   - Ensure component imports are correct
   - Validate Figma URLs

3. **Connection validation fails**
   - Verify Figma node IDs
   - Check component export names
   - Ensure proper file structure

## 📚 Resources

- [Figma Code Connect Documentation](https://help.figma.com/hc/en-us/articles/23920389749655-Code-Connect)
- [Scout Dashboard Figma File](https://www.figma.com/design/Rjh4xxbrZr8otmfpPqiVPC/)
- [React Components Guide](./docs/components.md)
- [Design System Documentation](./docs/design-system.md)

## 🤝 Contributing

1. Create a feature branch
2. Update Figma designs if needed
3. Create/update Code Connect mappings
4. Test thoroughly
5. Submit PR with screenshots

## 📄 License

Copyright © 2025 Scout Dashboard. All rights reserved.
