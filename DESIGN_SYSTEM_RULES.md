# Design System Rules for AI-AAS Hardened Lakehouse

## Overview
This document defines the comprehensive design system rules for integrating Figma designs with the Scout platform codebase using the Model Context Protocol (MCP).

## 1. Project Structure & Architecture

### Repository Organization
```
/Users/tbwa/ai-aas-hardened-lakehouse/
├── apps/                    # Application workspaces
│   ├── scout-ui/           # Main UI library with Figma Connect
│   ├── scout-dashboard/    # Next.js dashboard application
│   └── pi-edge/           # Edge device application
├── packages/              # Shared packages
├── components/           # Global component library
├── supabase/            # Backend and edge functions
└── platform/           # Platform-specific configurations
```

### Key Applications
- **scout-ui**: Component library with Figma Code Connect integration
- **scout-dashboard**: Production Next.js application
- **pi-edge**: React/Vite edge application

## 2. Design Token System

### Color Palette
```typescript
// Primary brand colors - Scout/TBWA theme
const colors = {
  brand: {
    primary: '#0057ff',    // TBWA Blue
    secondary: '#10B981',  // Success Green
    accent: '#F59E0B',     // Warning Orange
    danger: '#EF4444',     // Error Red
    dark: '#1F2937',       // Dark Gray
    light: '#F9FAFB'       // Light Gray
  },
  
  // Semantic colors
  semantic: {
    success: '#10B981',
    warning: '#F59E0B',
    error: '#EF4444',
    info: '#3B82F6'
  },
  
  // Gradient definitions
  gradients: {
    primary: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    success: 'linear-gradient(135deg, #10B981 0%, #059669 100%)',
    danger: 'linear-gradient(135deg, #F59E0B 0%, #DC2626 100%)'
  }
}
```

### Typography Scale
```typescript
const typography = {
  fontFamily: {
    sans: ['Inter', 'system-ui', 'sans-serif'],
    mono: ['Fira Code', 'monospace']
  },
  
  fontSize: {
    xs: '0.75rem',      // 12px
    sm: '0.875rem',     // 14px
    base: '1rem',       // 16px
    lg: '1.125rem',     // 18px
    xl: '1.25rem',      // 20px
    '2xl': '1.5rem',    // 24px
    '3xl': '1.875rem',  // 30px
    '4xl': '2.25rem'    // 36px
  },
  
  fontWeight: {
    normal: 400,
    medium: 500,
    semibold: 600,
    bold: 700
  }
}
```

### Spacing System
```typescript
const spacing = {
  0: '0px',
  1: '0.25rem',   // 4px
  2: '0.5rem',    // 8px
  3: '0.75rem',   // 12px
  4: '1rem',      // 16px
  5: '1.25rem',   // 20px
  6: '1.5rem',    // 24px
  8: '2rem',      // 32px
  10: '2.5rem',   // 40px
  12: '3rem',     // 48px
  16: '4rem',     // 64px
  20: '5rem',     // 80px
  24: '6rem'      // 96px
}
```

## 3. Component Architecture

### Component Structure Pattern
```typescript
// Standard component file structure
// components/ComponentName/
// ├── ComponentName.tsx        // Main component
// ├── ComponentName.figma.tsx  // Figma Code Connect
// ├── ComponentName.test.tsx   // Tests
// ├── ComponentName.stories.tsx // Storybook stories
// └── index.ts                 // Export

// Example component template
import React from 'react';
import { cn } from '@/lib/utils';

export interface ComponentNameProps {
  className?: string;
  variant?: 'primary' | 'secondary';
  size?: 'sm' | 'md' | 'lg';
  children?: React.ReactNode;
}

export const ComponentName: React.FC<ComponentNameProps> = ({
  className,
  variant = 'primary',
  size = 'md',
  children
}) => {
  return (
    <div className={cn(
      'component-base-styles',
      variant === 'primary' && 'variant-primary-styles',
      size === 'md' && 'size-md-styles',
      className
    )}>
      {children}
    </div>
  );
};
```

## 4. Figma Code Connect Integration

### Setup Configuration
```json
// figma.config.json
{
  "codeConnect": {
    "include": ["apps/scout-ui/src/**/*.figma.tsx"],
    "parser": "react"
  }
}
```

### Figma Connect File Pattern
```typescript
// ComponentName.figma.tsx
import { figma } from '@figma/code-connect';
import { ComponentName } from './ComponentName';

figma.connect(ComponentName, 'FIGMA_NODE_URL', {
  props: {
    variant: figma.enum('Variant', {
      Primary: 'primary',
      Secondary: 'secondary'
    }),
    size: figma.enum('Size', {
      Small: 'sm',
      Medium: 'md',
      Large: 'lg'
    })
  },
  example: ({ variant, size }) => (
    <ComponentName variant={variant} size={size}>
      Content
    </ComponentName>
  )
});
```

## 5. Styling Approach

### Tailwind CSS Configuration
```typescript
// tailwind.config.ts
import type { Config } from 'tailwindcss'

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#0057ff',  // Primary brand color
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a'
        }
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-in-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite'
      }
    }
  },
  plugins: []
}
```

### CSS-in-JS Pattern (when needed)
```typescript
// For dynamic styles that can't be handled by Tailwind
const dynamicStyles = {
  transform: `translateX(${offset}px)`,
  background: `linear-gradient(${angle}deg, ${color1}, ${color2})`
};
```

## 6. Data Integration & State Management

### Supabase Integration
```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Standard query pattern
export async function fetchScoutData(table: string, filters?: any) {
  let query = supabase.from(table).select('*');
  
  if (filters) {
    Object.entries(filters).forEach(([key, value]) => {
      query = query.eq(key, value);
    });
  }
  
  const { data, error } = await query;
  if (error) throw error;
  return data;
}
```

### State Management with Zustand
```typescript
// store/useFilters.ts
import { create } from 'zustand';

interface FilterState {
  timeRange: string;
  department: string;
  client: string;
  setFilter: (key: string, value: any) => void;
  resetFilters: () => void;
}

export const useFilters = create<FilterState>((set) => ({
  timeRange: '30d',
  department: 'all',
  client: 'all',
  setFilter: (key, value) => set((state) => ({ ...state, [key]: value })),
  resetFilters: () => set({ timeRange: '30d', department: 'all', client: 'all' })
}));
```

## 7. Icon System

### Lucide React Icons
```typescript
// Standard icon imports
import { 
  TrendingUp, 
  TrendingDown, 
  Calendar, 
  Search, 
  Bell, 
  ChevronDown 
} from 'lucide-react';

// Icon component wrapper
export const Icon: React.FC<{ name: string; className?: string }> = ({ 
  name, 
  className 
}) => {
  const IconComponent = iconMap[name];
  return <IconComponent className={cn('w-5 h-5', className)} />;
};
```

## 8. Asset Management

### Image Handling
```typescript
// Asset locations
// - Static assets: /public/
// - Component assets: /src/assets/
// - Dynamic images: Supabase Storage

// Image component pattern
import Image from 'next/image';

export const OptimizedImage = ({ src, alt, ...props }) => (
  <Image
    src={src}
    alt={alt}
    loading="lazy"
    placeholder="blur"
    {...props}
  />
);
```

## 9. Performance Optimization

### Code Splitting
```typescript
// Dynamic imports for heavy components
const HeavyComponent = dynamic(() => import('./HeavyComponent'), {
  loading: () => <Skeleton />,
  ssr: false
});
```

### Memoization Patterns
```typescript
// Use React.memo for expensive renders
export const ExpensiveComponent = React.memo(({ data }) => {
  return <ComplexVisualization data={data} />;
}, (prevProps, nextProps) => {
  return prevProps.data.id === nextProps.data.id;
});

// Use useMemo for expensive calculations
const processedData = useMemo(() => {
  return expensiveDataProcessing(rawData);
}, [rawData]);
```

## 10. Responsive Design

### Breakpoint System
```typescript
const breakpoints = {
  sm: '640px',   // Mobile landscape
  md: '768px',   // Tablet
  lg: '1024px',  // Desktop
  xl: '1280px',  // Wide desktop
  '2xl': '1536px' // Ultra-wide
};

// Responsive component pattern
<div className="
  grid 
  grid-cols-1 
  sm:grid-cols-2 
  lg:grid-cols-3 
  xl:grid-cols-4 
  gap-4
">
  {/* Content */}
</div>
```

## 11. Animation & Transitions

### Standard Animations
```css
/* Defined in globals.css */
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slideUp {
  from { transform: translateY(20px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

/* Usage in components */
.animate-fade-in {
  animation: fadeIn 0.5s ease-in-out;
}

.animate-slide-up {
  animation: slideUp 0.3s ease-out;
}
```

## 12. Accessibility Standards

### ARIA Patterns
```typescript
// Accessible component patterns
<button
  aria-label="Close dialog"
  aria-pressed={isPressed}
  role="button"
  tabIndex={0}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      handleClick();
    }
  }}
>
  {children}
</button>
```

### Focus Management
```typescript
// Focus trap for modals
import { FocusTrap } from '@/components/FocusTrap';

<FocusTrap active={isOpen}>
  <Modal>{/* Content */}</Modal>
</FocusTrap>
```

## 13. Testing Patterns

### Component Testing
```typescript
// ComponentName.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { ComponentName } from './ComponentName';

describe('ComponentName', () => {
  it('renders with default props', () => {
    render(<ComponentName />);
    expect(screen.getByRole('button')).toBeInTheDocument();
  });
  
  it('handles click events', () => {
    const handleClick = jest.fn();
    render(<ComponentName onClick={handleClick} />);
    fireEvent.click(screen.getByRole('button'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });
});
```

## 14. Documentation Standards

### Component Documentation
```typescript
/**
 * ComponentName - Brief description
 * 
 * @component
 * @example
 * ```tsx
 * <ComponentName 
 *   variant="primary"
 *   size="md"
 *   onClick={() => console.log('clicked')}
 * >
 *   Button Text
 * </ComponentName>
 * ```
 * 
 * @param {ComponentNameProps} props - Component props
 * @returns {JSX.Element} Rendered component
 */
```

## 15. Migration & Deployment

### Scout Schema Integration
```sql
-- When creating new tables for UI features
CREATE TABLE IF NOT EXISTS scout.ui_components (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  component_name TEXT NOT NULL,
  figma_node_id TEXT,
  version TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Apply migrations using
-- apply_migration tool with scout schema
```

### Edge Function Deployment
```typescript
// supabase/functions/scout-ui-sync/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (req) => {
  // Handle UI state synchronization
  return new Response(
    JSON.stringify({ status: 'success' }),
    { headers: { 'Content-Type': 'application/json' } }
  );
});
```

## Usage in MCP Context

When converting Figma designs to code:

1. **Extract design tokens** from Figma using `get_variable_defs`
2. **Generate component code** using `get_code` 
3. **Apply design system rules** from this document
4. **Create Figma Connect files** for component mapping
5. **Test in Storybook** before production deployment
6. **Deploy to scout schema** using MCP migration tools

## File Naming Conventions

```
ComponentName.tsx           # PascalCase for components
useHookName.ts             # camelCase with 'use' prefix for hooks
component-name.module.css  # kebab-case for CSS modules
CONSTANT_NAME.ts           # UPPER_SNAKE_CASE for constants
function-name.ts           # kebab-case for utility functions
```

## Git Workflow Integration

```bash
# When adding new Figma-connected components
git add apps/scout-ui/src/components/NewComponent/
git commit -m "feat(scout-ui): add NewComponent with Figma Connect"

# Push to GitHub using MCP tools
github:push_files
```

This design system ensures consistency across the Scout platform while maintaining flexibility for Figma-driven design updates.
