# Runbook: Design → Code → PR

## Overview

This runbook provides step-by-step instructions for converting Figma designs into production-ready React components using SuperClaude agents and MCP tools. The process ensures design fidelity, code quality, and proper integration with the Scout Dashboard platform.

## Prerequisites

### ✅ **Required Tools**
- Figma Desktop with Dev Mode enabled
- Claude Desktop with MCP configuration
- Node.js and pnpm package manager
- Git and GitHub CLI (`gh`)

### ✅ **Required Access**
- Figma file access (editor or developer permissions)
- Repository write access
- Claude Desktop MCP servers running

### ✅ **Verification**
```bash
# Check MCP server health
curl http://127.0.0.1:3845/health

# Verify Code Connect setup
pnpm run figma:connect:validate

# Confirm GitHub authentication
gh auth status
```

## Step-by-Step Process

### Step 1: Prepare Design in Figma

#### 1.1 Open Figma in Dev Mode
- Open Figma Desktop application
- Navigate to your design file
- **Enable Dev Mode** (toggle in top toolbar)
- Select the component you want to convert

#### 1.2 Extract Component Information
- **Right sidebar** → "Copy link" button
- Extract information from the URL:
  ```
  https://www.figma.com/file/{FILE_KEY}/Design-Name?node-id={NODE_ID}
  ```
- Note component name and intended props

#### 1.3 Document Component Requirements
```yaml
# Example: KpiTile Component Requirements
component_name: "KpiTile"
figma_file_key: "abc123xyz789"
node_id: "45:67"
props:
  label: 
    type: "string"
    required: true
    description: "Display label for the KPI"
  value:
    type: "string | number" 
    required: true
    description: "KPI value to display"
  delta:
    type: "number"
    required: false
    description: "Percentage change (positive/negative)"
  state:
    type: "'default' | 'loading' | 'error' | 'empty'"
    required: false
    default: "'default'"
    description: "Component state for styling"
```

### Step 2: Generate Component Code

#### 2.1 Create Component Stub (Automated)
```bash
# Generate component directory and files
./scripts/agents/superclaude.sh figma:stub KpiTile
```

**Expected Output**:
```
✅ Figma Code Connect stub created at apps/scout-ui/src/components/KpiTile/KpiTile.figma.tsx
📝 Next steps:
   1. Open Figma in Dev Mode  
   2. Navigate to your component
   3. Copy the component link from right sidebar
   4. Update FILE_KEY and NODE_ID in apps/scout-ui/src/components/KpiTile/KpiTile.figma.tsx
   5. Map Figma properties to component props
```

#### 2.2 Implement React Component (Manual)
Create the React component at `apps/scout-ui/src/components/KpiTile/KpiTile.tsx`:

```typescript
import React from "react";

export type KpiTileProps = {
  label: string;
  value: string | number;
  delta?: number;
  state?: "default" | "loading" | "error" | "empty";
  onClick?: () => void;
};

export const KpiTile: React.FC<KpiTileProps> = ({
  label, value, delta, state = "default", onClick
}) => {
  const isPositive = typeof delta === "number" && delta >= 0;
  const deltaColor = 
    state === "error" ? "text-red-600"
  : state === "loading" ? "text-gray-400"  
  : state === "empty" ? "text-gray-500"
  : isPositive ? "text-emerald-600"
  : "text-rose-600";

  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full text-left rounded-lg border border-gray-200 bg-white p-4 shadow-sm hover:shadow-md focus:outline-none focus:ring-2 focus:ring-brand-turquoise/60 transition"
      aria-busy={state === "loading"}
      disabled={state === "loading" || state === "empty"}
    >
      <div className="text-sm text-gray-600">{label}</div>
      <div className="mt-1 text-3xl font-semibold text-gray-900">{value}</div>
      {typeof delta === "number" && (
        <div className={`mt-1 text-sm ${deltaColor}`}>
          {isPositive ? "▲" : "▼"} {Math.abs(delta).toFixed(1)}%
        </div>
      )}
    </button>
  );
};
```

#### 2.3 Configure Code Connect Mapping
Update `apps/scout-ui/src/components/KpiTile/KpiTile.figma.tsx`:

```typescript
import { connect, figma } from "@figma/code-connect";
import { KpiTile } from "./KpiTile";

// Replace with your actual Figma file key and node ID
const FILE_KEY = "abc123xyz789";  // From Step 1.2
const NODE_ID = "45:67";          // From Step 1.2

export default connect(KpiTile, figma.component(FILE_KEY, NODE_ID), {
  props: {
    label: figma.string("Label", "Revenue"),
    value: figma.string("Value", "₱1.23M"), 
    delta: figma.number("Delta %", 4.2),
    state: figma.enum("State", ["default", "loading", "error", "empty"], "default"),
  },

  example: {
    label: "Revenue",
    value: "₱1.23M",
    delta: 4.2,
    state: "default",
  },

  variants: [
    { props: { state: "loading" }, title: "Loading State" },
    { props: { state: "empty" }, title: "Empty State" },
    { props: { state: "error" }, title: "Error State" },
    { props: { delta: -2.5 }, title: "Negative Delta" },
  ],
});
```

### Step 3: Local Validation

#### 3.1 Validate Code Connect Mapping
```bash
# Parse and validate mapping
pnpm run figma:connect:validate
```

**Expected Output**:
```
Config file found, parsing /Users/tbwa/ai-aas-hardened-lakehouse using specified include globs
✅ Code Connect validation passed
```

#### 3.2 Type Check and Lint
```bash
# Check TypeScript compilation
pnpm run type-check

# Run linting
pnpm run lint
```

#### 3.3 Test in Storybook (Optional)
Create `apps/scout-ui/src/components/KpiTile/KpiTile.stories.tsx`:

```typescript
import type { Meta, StoryObj } from '@storybook/react';
import { KpiTile } from './KpiTile';

const meta: Meta<typeof KpiTile> = {
  title: 'Components/KpiTile',
  component: KpiTile,
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    label: 'Revenue',
    value: '₱1.23M',
    delta: 4.2,
  },
};

export const Loading: Story = {
  args: {
    label: 'Revenue',
    value: 'Loading...',
    state: 'loading',
  },
};

export const Error: Story = {
  args: {
    label: 'Revenue', 
    value: 'Error',
    state: 'error',
  },
};

export const NegativeDelta: Story = {
  args: {
    label: 'Revenue',
    value: '₱1.23M',
    delta: -2.1,
  },
};
```

### Step 4: Verify Figma Integration

#### 4.1 Test in Figma Dev Mode
- Open Figma Desktop in Dev Mode
- Navigate to your component
- **Right sidebar** should show:
  - Component props from React code
  - Example states and variants
  - Interactive prop controls

#### 4.2 Verify Prop Mapping
- Test different prop values in Figma
- Confirm component states display correctly
- Check variant switching works

### Step 5: Create Pull Request

#### 5.1 Commit Changes
```bash
# Stage component files
git add apps/scout-ui/src/components/KpiTile/

# Commit with descriptive message
git commit -m "feat: add KpiTile component with Code Connect mapping

- Implement responsive KPI tile with delta indicators
- Add Code Connect mapping for Figma integration  
- Include loading, error, and empty states
- Add comprehensive Storybook stories"
```

#### 5.2 Create Pull Request
```bash
# Create feature branch  
git checkout -b feat/kpi-tile-component

# Push to remote
git push -u origin feat/kpi-tile-component

# Create pull request
gh pr create \
  --title "feat: add KpiTile component with Code Connect mapping" \
  --body "## Summary
- New KPI tile component for Scout Dashboard
- Code Connect integration for Figma Dev Mode
- Comprehensive state management and accessibility

## Testing
- ✅ Code Connect mapping validates
- ✅ TypeScript compilation passes
- ✅ All prop variants work in Figma
- ✅ Storybook stories created

## Screenshots
[Add screenshots of Figma integration]"
```

### Step 6: CI/CD Validation

#### 6.1 Automated Checks
The following GitHub Actions will run automatically:

- ✅ **figma-code-connect**: Validates Code Connect mappings
- ✅ **type-check**: TypeScript compilation  
- ✅ **lint**: ESLint and Prettier formatting
- ✅ **build**: Component builds successfully
- ✅ **test**: Unit tests pass (if created)

#### 6.2 Manual Review
- Figma integration works as expected
- Component meets accessibility requirements
- Code follows team conventions
- Documentation is complete

#### 6.3 Deployment
After approval and merge:
- Component available in Figma Dev Mode
- Storybook updated with new component
- Available for use in other applications

## Troubleshooting

### ❌ **Code Connect Validation Fails**

**Error**: `Cannot parse .figma.tsx file`

**Solution**:
```bash
# Check syntax errors
pnpm run figma:connect:parse

# Common fixes:
# 1. Verify FILE_KEY and NODE_ID are strings (quoted)
# 2. Check import paths are correct
# 3. Ensure figma.component() call matches exported component
```

### ❌ **Figma Shows "No Code Connect"**

**Error**: Component not showing props in Dev Mode

**Solution**:
1. Verify Figma file key is correct in `.figma.tsx`
2. Check node ID matches exactly (case-sensitive)
3. Ensure component is published or in correct file
4. Try refreshing Figma Dev Mode panel

### ❌ **TypeScript Compilation Errors**

**Error**: Type mismatches or import errors

**Solution**:
```bash
# Check component props match interface
# Verify import paths are correct
# Run type check with verbose output
pnpm run type-check --verbose
```

### ❌ **CI Pipeline Failures**

**Error**: GitHub Actions failing

**Solution**:
```bash
# Check specific failure in GitHub Actions log
# Common fixes:
# 1. Update package.json dependencies
# 2. Fix linting errors
# 3. Resolve merge conflicts
# 4. Update lockfiles
```

## Quality Checklist

### ✅ **Before Creating PR**
- [ ] Component implements all required props from design
- [ ] Code Connect mapping validates successfully  
- [ ] TypeScript compilation passes without errors
- [ ] Component handles all specified states (loading, error, empty)
- [ ] Accessibility attributes included (ARIA labels, keyboard navigation)
- [ ] Responsive design works on mobile/tablet/desktop
- [ ] Storybook stories cover main use cases

### ✅ **During Review**  
- [ ] Figma Dev Mode shows component props correctly
- [ ] Design fidelity matches Figma mockups
- [ ] Component reusability considered
- [ ] Performance impact acceptable
- [ ] Security implications reviewed
- [ ] Documentation complete and accurate

### ✅ **After Merge**
- [ ] Component available in Figma library
- [ ] Storybook updated with new component
- [ ] Design system documentation updated
- [ ] Team notified of new component availability

## Advanced Workflows

### **Multi-Component Systems**
For design systems with multiple related components:

```bash
# Generate multiple components
./scripts/agents/superclaude.sh figma:stub KpiTile
./scripts/agents/superclaude.sh figma:stub KpiCard  
./scripts/agents/superclaude.sh figma:stub KpiGrid

# Create shared types
# apps/scout-ui/src/types/kpi.types.ts
```

### **Complex State Management**
For components with complex interactions:

```typescript
// Add useReducer or custom hooks
// Include integration with global state (Zustand/Redux)
// Add loading and error boundaries
```

### **Design Token Integration** 
For consistent styling across components:

```typescript
// Use design tokens from scout-ui theme
// Implement CSS custom properties
// Add dark mode support
```

---

**Last Updated**: August 28, 2025  
**Runbook Version**: 1.0.0  
**Contact**: TBWA Frontend Team