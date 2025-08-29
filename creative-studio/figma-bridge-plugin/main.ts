// Claude Bridge Plugin - Write operations for Figma/FigJam
// Runs in the Figma/FigJam editor and executes commands from MCP Hub

figma.showUI(__html__, { width: 320, height: 180, themeColors: true });

type BridgeCmd =
  | { type: "create-sticky"; page?: string; text: string; x?: number; y?: number; color?: string }
  | { type: "create-frame"; name: string; width: number; height: number; x?: number; y?: number }
  | { type: "create-component"; name: string; width: number; height: number }
  | { type: "rename-selection"; name: string }
  | { type: "apply-variable"; collection: string; variable: string; value: string }
  | { type: "place-component"; key: string; name?: string; x?: number; y?: number }
  | { type: "create-dashboard-layout"; title: string; grid: { cols: number; gutter: number }; tiles: any[] }
  | { type: "apply-brand-tokens"; tokens: Record<string, any> }
  | { type: "log-usage"; component: string; action: string; context?: any };

interface UsageLog {
  component_id: string;
  action: string;
  platform: string;
  context: any;
  user_id: string;
  timestamp: string;
}

// Usage logging for Design System Analytics
const logUsage = async (component: string, action: string, context?: any) => {
  const log: UsageLog = {
    component_id: component,
    action: action,
    platform: figma.editorType,
    context: context || {},
    user_id: figma.currentUser?.id || 'anonymous',
    timestamp: new Date().toISOString()
  };
  
  // Send to MCP Hub for Supabase storage
  figma.ui.postMessage({ 
    type: 'usage-log', 
    data: log 
  });
};

figma.ui.onmessage = async (msg: BridgeCmd) => {
  try {
    // FigJam operations
    if (msg.type === "create-sticky" && figma.editorType === "figjam") {
      const node = figma.createSticky();
      node.text.characters = msg.text;
      node.x = msg.x ?? 100;
      node.y = msg.y ?? 100;
      
      // Apply color if specified
      if (msg.color) {
        const colorMap: Record<string, RGB> = {
          yellow: { r: 1, g: 0.9, b: 0.2 },
          blue: { r: 0.2, g: 0.6, b: 1 },
          green: { r: 0.2, g: 0.8, b: 0.4 },
          pink: { r: 1, g: 0.4, b: 0.7 }
        };
        if (msg.color && colorMap[msg.color]) {
          node.fills = [{ type: 'SOLID', color: colorMap[msg.color] }];
        }
      }
      
      figma.currentPage.appendChild(node);
      figma.currentPage.selection = [node];
      figma.notify(`Sticky "${msg.text}" created`);
      
      await logUsage('sticky', 'create', { text: msg.text, color: msg.color });
    }

    // Figma frame operations
    if (msg.type === "create-frame" && figma.editorType === "figma") {
      const frame = figma.createFrame();
      frame.name = msg.name;
      frame.resize(msg.width, msg.height);
      frame.x = msg.x ?? 100;
      frame.y = msg.y ?? 100;
      
      // Apply auto-layout for dashboard tiles
      frame.layoutMode = "VERTICAL";
      frame.paddingTop = frame.paddingBottom = frame.paddingLeft = frame.paddingRight = 16;
      frame.itemSpacing = 8;
      frame.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
      
      figma.currentPage.appendChild(frame);
      figma.currentPage.selection = [frame];
      figma.notify(`Frame "${msg.name}" created`);
      
      await logUsage('frame', 'create', { name: msg.name, width: msg.width, height: msg.height });
    }

    // Create component from selection
    if (msg.type === "create-component" && figma.editorType === "figma") {
      if (figma.currentPage.selection.length === 0) {
        figma.notify("Select elements to create component", { error: true });
        return;
      }
      
      const component = figma.createComponent();
      component.name = msg.name;
      component.resize(msg.width, msg.height);
      
      figma.notify(`Component "${msg.name}" created`);
      await logUsage('component', 'create', { name: msg.name });
    }

    // Rename selection
    if (msg.type === "rename-selection") {
      if (figma.currentPage.selection.length === 0) {
        figma.notify("Select elements to rename", { error: true });
        return;
      }
      
      for (const node of figma.currentPage.selection) {
        node.name = msg.name;
      }
      figma.notify(`${figma.currentPage.selection.length} items renamed to "${msg.name}"`);
      
      await logUsage('selection', 'rename', { name: msg.name, count: figma.currentPage.selection.length });
    }

    // Place component instance
    if (msg.type === "place-component") {
      try {
        const component = await figma.importComponentByKeyAsync(msg.key);
        const instance = component.createInstance();
        instance.x = msg.x ?? 100;
        instance.y = msg.y ?? 100;
        
        if (msg.name) instance.name = msg.name;
        
        figma.currentPage.appendChild(instance);
        figma.currentPage.selection = [instance];
        figma.notify(`Component instance "${msg.name || component.name}" placed`);
        
        await logUsage('component-instance', 'place', { key: msg.key, name: msg.name });
      } catch (e) {
        figma.notify(`Failed to place component: ${e}`, { error: true });
      }
    }

    // Create dashboard layout from DashboardML
    if (msg.type === "create-dashboard-layout" && figma.editorType === "figma") {
      // Create main dashboard frame
      const dashFrame = figma.createFrame();
      dashFrame.name = msg.title;
      dashFrame.resize(1440, 1024); // Standard dashboard size
      dashFrame.x = 100;
      dashFrame.y = 100;
      
      // Apply grid layout
      dashFrame.layoutGrids = [{
        pattern: "COLUMNS",
        sectionSize: 1440 / msg.grid.cols,
        count: msg.grid.cols,
        alignment: "MIN",
        gutterSize: msg.grid.gutter,
        offset: 0,
        color: { r: 0.8, g: 0.8, b: 0.8, a: 1 },
        visible: true
      }];
      
      // Create header with filters
      const header = figma.createFrame();
      header.name = "Dashboard Header";
      header.resize(1440, 80);
      header.y = 0;
      header.fills = [{ type: 'SOLID', color: { r: 0.97, g: 0.97, b: 0.97 } }];
      dashFrame.appendChild(header);
      
      // Create tiles from DashboardML
      for (const tile of msg.tiles) {
        const tileFrame = figma.createFrame();
        tileFrame.name = `Tile: ${tile.id}`;
        
        // Calculate position based on grid
        const colWidth = 1440 / msg.grid.cols;
        tileFrame.resize(
          colWidth * tile.w - msg.grid.gutter,
          tile.h * 120 // Approximate height per row
        );
        tileFrame.x = colWidth * tile.x + (msg.grid.gutter / 2);
        tileFrame.y = 80 + (tile.y * 120) + msg.grid.gutter; // Account for header
        
        // Style based on tile type
        if (tile.type === 'metric') {
          tileFrame.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
          // Add KPI styling
        } else if (tile.type === 'line' || tile.type === 'bar') {
          tileFrame.fills = [{ type: 'SOLID', color: { r: 0.99, g: 0.99, b: 1 } }];
          // Add chart styling
        }
        
        tileFrame.cornerRadius = 8;
        tileFrame.effects = [{
          type: "DROP_SHADOW",
          color: { r: 0, g: 0, b: 0, a: 0.1 },
          offset: { x: 0, y: 2 },
          radius: 4,
          visible: true,
          blendMode: "NORMAL"
        }];
        
        dashFrame.appendChild(tileFrame);
      }
      
      figma.currentPage.appendChild(dashFrame);
      figma.currentPage.selection = [dashFrame];
      figma.notify(`Dashboard layout "${msg.title}" created with ${msg.tiles.length} tiles`);
      
      await logUsage('dashboard-layout', 'create', { title: msg.title, tiles: msg.tiles.length });
    }

    // Apply brand tokens
    if (msg.type === "apply-brand-tokens") {
      // Apply to selection or create style library
      const selection = figma.currentPage.selection;
      
      if (selection.length > 0) {
        for (const node of selection) {
          // Apply colors, typography, spacing from tokens
          if ('fills' in node && msg.tokens.colors) {
            // Apply primary color as example
            if (msg.tokens.colors.primary) {
              const color = hexToRgb(msg.tokens.colors.primary);
              if (color) {
                node.fills = [{ type: 'SOLID', color }];
              }
            }
          }
          
          // Apply typography tokens
          if ('fontName' in node && msg.tokens.typography?.heading) {
            node.fontName = { 
              family: msg.tokens.typography.heading.fontFamily || "Inter", 
              style: "Medium" 
            };
          }
        }
        figma.notify(`Brand tokens applied to ${selection.length} items`);
      }
      
      await logUsage('brand-tokens', 'apply', { tokenCount: Object.keys(msg.tokens).length });
    }

    figma.ui.postMessage({ ok: true, type: 'command-complete' });
    
  } catch (e) {
    figma.notify(`Error: ${String(e)}`, { error: true });
    figma.ui.postMessage({ ok: false, error: String(e) });
  }
};

// Helper function
function hexToRgb(hex: string): { r: number; g: number; b: number } | null {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? {
    r: parseInt(result[1], 16) / 255,
    g: parseInt(result[2], 16) / 255,
    b: parseInt(result[3], 16) / 255
  } : null;
}