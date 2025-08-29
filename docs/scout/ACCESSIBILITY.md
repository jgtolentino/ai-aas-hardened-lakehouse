# Scout Dashboard Accessibility Guide

**Owner**: @D-Chan @L-Wong  
**Standard**: WCAG 2.1 Level AA  
**Last Audit**: 2025-01-26  
**Next Audit**: 2025-02-26  

## WCAG Compliance

### Level A Requirements (Must Have)
- ✅ **1.1.1 Non-text Content**: All images have alt text
- ✅ **1.3.1 Info and Relationships**: Proper heading hierarchy
- ✅ **1.4.1 Use of Color**: Color not sole indicator
- ✅ **2.1.1 Keyboard**: All functions keyboard accessible
- ✅ **2.4.2 Page Titled**: Descriptive page titles
- ✅ **3.1.1 Language of Page**: HTML lang attribute set
- ✅ **4.1.1 Parsing**: Valid HTML

### Level AA Requirements (Must Have)
- ✅ **1.4.3 Contrast (Minimum)**: 4.5:1 for normal text
- ✅ **1.4.4 Resize Text**: Works at 200% zoom
- ✅ **1.4.5 Images of Text**: Real text used
- 🟡 **1.4.10 Reflow**: Testing at 320px width
- ✅ **2.4.6 Headings and Labels**: Descriptive
- ✅ **2.4.7 Focus Visible**: Clear focus indicators
- ✅ **3.2.3 Consistent Navigation**: Same order

## Keyboard Navigation

### Global Shortcuts
| Key | Action |
|-----|--------|
| `Tab` | Navigate forward |
| `Shift + Tab` | Navigate backward |
| `Enter` | Activate button/link |
| `Space` | Check checkbox, activate button |
| `Esc` | Close modal/dropdown |
| `/` | Focus search |
| `?` | Show keyboard shortcuts |

### Dashboard Navigation
| Key | Action |
|-----|--------|
| `g` then `h` | Go to home |
| `g` then `a` | Go to analytics |
| `g` then `g` | Go to geographic |
| `g` then `c` | Go to consumer |
| `g` then `r` | Go to reports |

### Data Table Navigation
| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate rows |
| `←` / `→` | Navigate columns |
| `Home` | First cell in row |
| `End` | Last cell in row |
| `Ctrl + Home` | First cell in table |
| `Ctrl + End` | Last cell in table |
| `Space` | Select row |
| `Ctrl + A` | Select all |

## ARIA Labels

### Required ARIA Attributes

#### Navigation
```html
<nav aria-label="Main navigation">
  <ul role="list">
    <li>
      <a href="/dashboard" aria-current="page">Dashboard</a>
    </li>
  </ul>
</nav>
```

#### KPI Cards
```html
<div role="article" aria-labelledby="revenue-title">
  <h3 id="revenue-title">Revenue</h3>
  <p aria-live="polite" aria-atomic="true">₱1,234,567</p>
  <span aria-label="12% increase from last period">↑ 12%</span>
</div>
```

#### Charts
```html
<div role="img" 
     aria-label="Revenue trend chart showing 15% growth over 6 months">
  <canvas id="chart"></canvas>
</div>
<table class="sr-only">
  <!-- Data table alternative for screen readers -->
</table>
```

#### Forms
```html
<label for="date-range">
  Date Range
  <span aria-label="required">*</span>
</label>
<input id="date-range" 
       type="text" 
       aria-describedby="date-help"
       aria-invalid="false"
       required>
<span id="date-help">Format: YYYY-MM-DD</span>
```

#### Modals
```html
<div role="dialog" 
     aria-labelledby="modal-title" 
     aria-describedby="modal-desc"
     aria-modal="true">
  <h2 id="modal-title">Export Data</h2>
  <p id="modal-desc">Choose export format</p>
</div>
```

#### Loading States
```html
<div aria-busy="true" aria-live="polite">
  <span class="sr-only">Loading chart data...</span>
  <!-- Skeleton UI -->
</div>
```

## Focus Management

### Focus Order
1. Skip to main content link
2. Header logo
3. Main navigation
4. User menu
5. Search
6. Sidebar navigation
7. Page header
8. Primary actions
9. Main content
10. Footer

### Focus Trap Contexts
- Modals
- Dropdowns
- Date pickers
- Autocomplete

### Focus Restoration
```javascript
// Save focus before opening modal
const previousFocus = document.activeElement;

// Open modal and trap focus
openModal();
modal.focus();

// On close, restore focus
closeModal();
previousFocus?.focus();
```

## Color Contrast

### Text Contrast Ratios
| Element | Foreground | Background | Ratio | Status |
|---------|------------|------------|-------|--------|
| Body text | #1F2937 | #FFFFFF | 12.63:1 | ✅ AAA |
| Heading | #111827 | #FFFFFF | 15.3:1 | ✅ AAA |
| Link | #1E40AF | #FFFFFF | 5.97:1 | ✅ AA |
| Error text | #DC2626 | #FEF2F2 | 5.13:1 | ✅ AA |
| Disabled | #9CA3AF | #F3F4F6 | 3.03:1 | ⚠️ Below AA |

### Non-Text Contrast
| Element | Contrast | Status |
|---------|----------|--------|
| Input borders | 3.1:1 | ✅ Meets |
| Focus indicators | 4.5:1 | ✅ Meets |
| Icon buttons | 4.8:1 | ✅ Meets |
| Chart colors | 3.2:1 | ✅ Meets |

## Screen Reader Support

### Tested With
- ✅ NVDA (Windows) - v2024.4
- ✅ JAWS (Windows) - v2024
- ✅ VoiceOver (macOS) - Sonoma
- ✅ VoiceOver (iOS) - iOS 17
- 🟡 TalkBack (Android) - In testing

### Announcements
```javascript
// Live region for dynamic updates
const announce = (message, priority = 'polite') => {
  const region = document.getElementById('live-region');
  region.setAttribute('aria-live', priority);
  region.textContent = message;
};

// Usage
announce('Data updated successfully');
announce('Error: Invalid date range', 'assertive');
```

## Form Accessibility

### Error Handling
```html
<div role="alert" aria-live="assertive">
  <ul>
    <li>Email is required</li>
    <li>Password must be 8+ characters</li>
  </ul>
</div>
```

### Field Validation
```javascript
const validateField = (field) => {
  const error = getError(field);
  
  if (error) {
    field.setAttribute('aria-invalid', 'true');
    field.setAttribute('aria-describedby', `${field.id}-error`);
    
    const errorEl = document.getElementById(`${field.id}-error`);
    errorEl.textContent = error;
    errorEl.classList.remove('hidden');
  } else {
    field.setAttribute('aria-invalid', 'false');
  }
};
```

## Responsive Accessibility

### Touch Targets
- Minimum size: 44x44px
- Spacing: 8px minimum between targets
- Exceptions: Inline text links

### Zoom Support
- Tested at 200% zoom
- No horizontal scroll at 400% zoom + 1280px width
- Text remains readable
- Interactive elements remain clickable

## Testing Checklist

### Manual Testing
- [ ] Keyboard-only navigation
- [ ] Screen reader testing
- [ ] 200% zoom functionality
- [ ] High contrast mode
- [ ] Motion reduced mode
- [ ] Focus indicators visible
- [ ] Tab order logical

### Automated Testing
```javascript
// Run in CI/CD
npm run test:a11y

// Tools used:
// - axe-core
// - @testing-library/jest-dom
// - jest-axe
// - lighthouse
```

### Accessibility Score
```yaml
current_score:
  lighthouse: 98
  axe: 0 violations
  wave: 0 errors, 2 alerts
  
target_score:
  lighthouse: 100
  axe: 0 violations
  wave: 0 errors, 0 alerts
```

## Common Issues & Fixes

### Issue: Low contrast on hover states
**Fix**: Ensure 3:1 contrast ratio for all states
```css
.button:hover {
  /* Bad: #E5E7EB on white = 1.5:1 */
  /* Good: #9CA3AF on white = 3.03:1 */
  background: #9CA3AF;
}
```

### Issue: Missing focus indicators
**Fix**: Add visible focus styles
```css
:focus-visible {
  outline: 2px solid #1E40AF;
  outline-offset: 2px;
}
```

### Issue: Keyboard trap in modal
**Fix**: Implement focus trap utility
```javascript
import { createFocusTrap } from 'focus-trap';

const trap = createFocusTrap('#modal', {
  escapeDeactivates: true,
  returnFocusOnDeactivate: true
});
```

### Issue: Chart data not accessible
**Fix**: Provide data table alternative
```html
<figure>
  <canvas id="chart" role="img" aria-label="Sales chart"></canvas>
  <details>
    <summary>View data table</summary>
    <table><!-- Full data --></table>
  </details>
</figure>
```

## Resources

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- [Inclusive Components](https://inclusive-components.design/)
- [A11y Project Checklist](https://www.a11yproject.com/checklist/)

## Compliance Statement

Scout Dashboard is committed to WCAG 2.1 Level AA compliance. We conduct monthly automated tests and quarterly manual audits. Report issues to accessibility@example.com.

**Last Update**: 2025-01-26  
**Next Review**: 2025-02-26
