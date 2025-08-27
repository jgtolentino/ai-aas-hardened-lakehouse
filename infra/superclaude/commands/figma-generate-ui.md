# sc:figma-generate-ui

**Goal**: Generate React + Tailwind components from the currently selected Figma frame using MCP design context.

**Prompt (Claude/Cursor)**
```
Persona: Frontend Architect
Use the connected "Figma Dev Mode MCP" tools to read the selected frame's layout, variables, and components.
Output production-grade React 18 + Tailwind components that match the layout.
Respect our Scout 12-col grid and accessibility rules.
```

**Checklist**
- [ ] Read variables (colors, spacing, radii)
- [ ] Map components to our /packages/ui primitives where possible
- [ ] Enforce 12-col grid and responsive breakpoints
- [ ] Generate Storybook stories
- [ ] Add ARIA attributes and keyboard focus order

**Save to**
- `apps/scout-dashboard/src/components/generated/<frame-name>/`
- `apps/scout-dashboard/.stories/generated/<frame-name>.stories.tsx`
