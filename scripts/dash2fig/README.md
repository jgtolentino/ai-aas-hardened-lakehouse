# Dash2Fig: Figma Design-to-Code Extractor

A powerful script that extracts design tokens, components, and layouts from Figma files and generates corresponding React components with TypeScript support for the Scout Dashboard.

## Features

- **Design Token Extraction**: Automatically extracts colors, typography, spacing, shadows, and border styles
- **Component Generation**: Converts Figma components to React TypeScript components
- **CSS Custom Properties**: Generates CSS variables for consistent design system
- **Utility Classes**: Creates utility classes for typography and common styles
- **Type-Safe Props**: Generates TypeScript interfaces for component properties

## Setup

1. **Install Dependencies**:
   ```bash
   cd scripts/dash2fig
   npm install
   ```

2. **Get Figma Access Token**:
   - Go to [Figma Settings > Personal Access Tokens](https://www.figma.com/settings)
   - Create a new personal access token
   - Copy the token for use in environment variables

3. **Get Figma File ID**:
   - Open your Figma file in the browser
   - Copy the file ID from the URL: `https://www.figma.com/file/{FILE_ID}/...`

## Usage

### Environment Variables

Create a `.env` file or set environment variables:

```bash
# Required
FIGMA_ACCESS_TOKEN=your_figma_personal_access_token
FIGMA_FILE_ID=your_figma_file_id

# Optional
NODE_ENV=development
```

### Basic Extraction

```bash
# Extract from default file
npm run extract

# Extract from development file
npm run extract:dev

# Extract from production file  
npm run extract:prod

# Clean generated files
npm run clean
```

### Advanced Usage

```bash
# Direct node execution with custom file
FIGMA_FILE_ID=custom-file-id node figma-extract.js

# Extract specific components only
FIGMA_COMPONENT_FILTER="Dashboard,Chart" node figma-extract.js
```

## Output Structure

The script generates files in the following structure:

```
apps/scout-dashboard/src/
├── components/generated/
│   ├── index.ts              # Component exports
│   ├── DashboardCard.tsx     # Generated components
│   ├── ChartWidget.tsx
│   └── ...
├── styles/generated/
│   └── design-tokens.css     # Design system tokens
```

## Generated Component Example

```typescript
// Generated from Figma component
import React from 'react';
import './generated-styles.css';

export interface DashboardCardProps {
  title?: string;
  variant?: 'primary' | 'secondary';
  size?: 'small' | 'medium' | 'large';
  className?: string;
}

export const DashboardCard: React.FC<DashboardCardProps> = ({
  title = "Dashboard Card",
  variant = 'primary',
  size = 'medium',
  className = ''
}) => {
  return (
    <div className={`figma-component dashboard-card ${className}`} 
         style={{backgroundColor: 'var(--color-surface-primary)'}}>
      <span className="text-heading-medium">{title}</span>
    </div>
  );
};

export default DashboardCard;
```

## Design Token CSS Example

```css
:root {
  /* Colors */
  --color-primary-500: rgb(59, 130, 246);
  --color-surface-primary: rgba(255, 255, 255, 0.95);
  --color-text-primary: rgb(17, 24, 39);
  
  /* Typography */
  --typography-heading-large-font-size: 24px;
  --typography-heading-large-font-weight: 600;
  --typography-heading-large-line-height: 32px;
  
  /* Shadows */
  --shadow-card: 0px 4px 8px rgba(0, 0, 0, 0.1);
}

/* Typography Utilities */
.text-heading-large {
  font-size: var(--typography-heading-large-font-size);
  font-weight: var(--typography-heading-large-font-weight);
  line-height: var(--typography-heading-large-line-height);
}
```

## Figma File Structure Requirements

For optimal extraction, structure your Figma file with:

1. **Component Library**: Organized components in a dedicated page
2. **Design Tokens**: Use Figma styles for colors, typography, and effects
3. **Variants**: Use component variants for different states
4. **Naming Convention**: Use clear, descriptive names for components and styles

### Recommended Naming

- **Components**: `Dashboard Card`, `Chart Widget`, `Filter Panel`
- **Colors**: `Primary/500`, `Surface/Primary`, `Text/Primary`
- **Typography**: `Heading/Large`, `Body/Medium`, `Caption/Small`
- **Effects**: `Card Shadow`, `Focus Ring`, `Hover Glow`

## Integration with Scout Dashboard

The generated components integrate seamlessly with the Scout Dashboard:

```typescript
// Import generated components
import { DashboardCard, ChartWidget } from '../components/generated';

// Use in your dashboard
export const OverviewTab = () => {
  return (
    <div className="grid grid-cols-12 gap-6">
      <DashboardCard 
        title="Revenue Overview"
        variant="primary"
        className="col-span-6"
      />
      <ChartWidget 
        type="line"
        data={revenueData}
        className="col-span-6"
      />
    </div>
  );
};
```

## Configuration Options

The script supports various configuration options:

```javascript
// In figma-extract.js
const CONFIG = {
  figmaToken: process.env.FIGMA_ACCESS_TOKEN,
  fileId: process.env.FIGMA_FILE_ID,
  outputDir: '../../apps/scout-dashboard/src/components/generated',
  stylesDir: '../../apps/scout-dashboard/src/styles/generated',
  
  // Advanced options
  componentFilter: process.env.FIGMA_COMPONENT_FILTER?.split(','),
  skipImages: process.env.SKIP_IMAGES === 'true',
  generateIndex: process.env.GENERATE_INDEX !== 'false',
  cssFormat: process.env.CSS_FORMAT || 'css' // 'css' | 'scss' | 'styled-components'
};
```

## Error Handling

Common issues and solutions:

### Authentication Error
```
Error: FIGMA_ACCESS_TOKEN environment variable is required
```
**Solution**: Set your Figma personal access token

### File Not Found
```
Error: Figma file not found or access denied
```
**Solution**: Verify file ID and token permissions

### Rate Limiting
```
Error: Rate limit exceeded
```
**Solution**: Add delays between requests or use pagination

## Contributing

When extending the script:

1. **Add new extractors** in the `DesignTokenExtractor` class
2. **Enhance component generation** in the `ComponentGenerator` class  
3. **Update configuration** options as needed
4. **Test with various Figma file structures**

## Troubleshooting

### Debug Mode
```bash
DEBUG=true node figma-extract.js
```

### Verbose Output
```bash
VERBOSE=true npm run extract
```

### Test Connection
```bash
# Test Figma API access
curl -H "X-Figma-Token: YOUR_TOKEN" \
     https://api.figma.com/v1/files/YOUR_FILE_ID
```

## License

MIT License - see LICENSE file for details.