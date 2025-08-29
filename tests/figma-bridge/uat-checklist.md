# Figma Bridge UAT Test Suite

User Acceptance Testing checklist for TBWA Figma Bridge Plugin enabling write operations via Claude Code CLI.

## Test Environment Setup

### Prerequisites
- [ ] Figma Desktop application installed
- [ ] Node.js installed (v16+ required)
- [ ] TBWA Creative Bridge plugin installed in Figma
- [ ] MCP Hub running on localhost:8787
- [ ] Claude Code CLI configured with Figma MCP tools

### Setup Steps
1. [ ] Start MCP Hub: `./scripts/figma.sh start`
2. [ ] Verify bridge status: `./scripts/figma.sh status`
3. [ ] Install Figma plugin: `./scripts/figma.sh install`
4. [ ] Open Figma Desktop and run "TBWA Creative Bridge" plugin
5. [ ] Verify WebSocket connection shows "Connected to Claude MCP Hub"

## Functional Testing

### 1. WebSocket Connection
- [ ] **Test**: Plugin connects to MCP Hub on startup
  - **Expected**: Green "Connected" status in plugin UI
  - **Actual**: ________________
- [ ] **Test**: Auto-reconnect after MCP Hub restart
  - **Expected**: Plugin reconnects within 5 seconds
  - **Actual**: ________________
- [ ] **Test**: Graceful handling of connection failures
  - **Expected**: Clear error message, retry attempts
  - **Actual**: ________________

### 2. FigJam Sticky Note Operations
- [ ] **Test**: Create sticky note with text
  - **Command**: `figma_create_sticky({ text: "Test sticky" })`
  - **Expected**: Yellow sticky created with "Test sticky"
  - **Actual**: ________________
- [ ] **Test**: Create colored sticky notes
  - **Command**: `figma_create_sticky({ text: "Blue note", color: "blue" })`
  - **Expected**: Blue sticky note created
  - **Actual**: ________________
- [ ] **Test**: Position sticky notes
  - **Command**: `figma_create_sticky({ text: "Positioned", x: 200, y: 100 })`
  - **Expected**: Sticky created at coordinates (200, 100)
  - **Actual**: ________________
- [ ] **Test**: Invalid color handling
  - **Command**: `figma_create_sticky({ text: "Test", color: "invalid" })`
  - **Expected**: Defaults to yellow, shows warning
  - **Actual**: ________________

### 3. Figma Frame Operations
- [ ] **Test**: Create basic frame
  - **Command**: `figma_create_frame({ name: "Test Frame", width: 400, height: 300 })`
  - **Expected**: Frame created with specified dimensions
  - **Actual**: ________________
- [ ] **Test**: Position frames
  - **Command**: `figma_create_frame({ name: "Positioned", width: 200, height: 200, x: 300, y: 150 })`
  - **Expected**: Frame created at specified position
  - **Actual**: ________________
- [ ] **Test**: Large frame handling
  - **Command**: `figma_create_frame({ name: "Large", width: 2000, height: 1500 })`
  - **Expected**: Large frame created successfully
  - **Actual**: ________________
- [ ] **Test**: Invalid dimensions
  - **Command**: `figma_create_frame({ name: "Invalid", width: -100, height: 50000 })`
  - **Expected**: Error message, no frame created
  - **Actual**: ________________

### 4. Component Operations
- [ ] **Test**: Create component from selection
  - **Setup**: Select some elements in Figma
  - **Command**: `figma_create_component({ name: "Test Component", width: 100, height: 100 })`
  - **Expected**: Component created from selection
  - **Actual**: ________________
- [ ] **Test**: No selection error handling
  - **Setup**: Ensure nothing is selected
  - **Command**: `figma_create_component({ name: "Empty", width: 100, height: 100 })`
  - **Expected**: Error message about no selection
  - **Actual**: ________________
- [ ] **Test**: Place component instance (requires valid component key)
  - **Command**: `figma_place_component({ key: "valid_component_key" })`
  - **Expected**: Component instance placed on canvas
  - **Actual**: ________________

### 5. Selection Operations
- [ ] **Test**: Rename selected elements
  - **Setup**: Select multiple elements
  - **Command**: `figma_rename_selection({ name: "Renamed Element" })`
  - **Expected**: All selected elements renamed
  - **Actual**: ________________
- [ ] **Test**: Rename with no selection
  - **Setup**: Deselect all elements
  - **Command**: `figma_rename_selection({ name: "Nothing" })`
  - **Expected**: Error message about no selection
  - **Actual**: ________________

### 6. Dashboard Layout Creation
- [ ] **Test**: Create basic dashboard
  - **Command**: 
    ```javascript
    figma_create_dashboard_layout({
      title: "Test Dashboard",
      grid: { cols: 3, gutter: 16 },
      tiles: [
        { id: "kpi1", type: "metric", x: 0, y: 0, w: 1, h: 1 },
        { id: "chart1", type: "line", x: 1, y: 0, w: 2, h: 2 }
      ]
    })
    ```
  - **Expected**: Dashboard frame with header and positioned tiles
  - **Actual**: ________________
- [ ] **Test**: Complex dashboard layout
  - **Command**: Use dashboard with 10+ tiles across 4 columns
  - **Expected**: All tiles positioned correctly with proper spacing
  - **Actual**: ________________

### 7. Brand Token Application
- [ ] **Test**: Apply color tokens
  - **Setup**: Select elements in Figma
  - **Command**: 
    ```javascript
    figma_apply_brand_tokens({
      tokens: {
        colors: { primary: "#FF6B35", secondary: "#004E89" },
        typography: { heading: { fontFamily: "Inter" } }
      }
    })
    ```
  - **Expected**: Selected elements updated with brand colors
  - **Actual**: ________________

### 8. Error Handling & Validation
- [ ] **Test**: Malformed commands
  - **Command**: `figma_create_sticky({ invalid: true })`
  - **Expected**: Validation error with helpful message
  - **Actual**: ________________
- [ ] **Test**: Extremely large values
  - **Command**: `figma_create_frame({ name: "Huge", width: 999999, height: 999999 })`
  - **Expected**: Values clamped to safe limits or error
  - **Actual**: ________________
- [ ] **Test**: Empty/null commands
  - **Command**: Send empty command object
  - **Expected**: Clear error message
  - **Actual**: ________________

## Performance Testing

### 1. Response Times
- [ ] **Test**: Single command execution time
  - **Metric**: Time from command send to completion
  - **Target**: < 1 second for simple operations
  - **Actual**: ________________
- [ ] **Test**: Batch command execution
  - **Setup**: Send 10 commands rapidly
  - **Target**: All complete within 10 seconds
  - **Actual**: ________________

### 2. Resource Usage
- [ ] **Test**: Memory usage during operation
  - **Tool**: Monitor Figma process memory
  - **Target**: No significant memory leaks
  - **Actual**: ________________
- [ ] **Test**: Plugin UI responsiveness
  - **Action**: Interact with plugin UI during commands
  - **Target**: UI remains responsive
  - **Actual**: ________________

## Security Testing

### 1. Input Sanitization
- [ ] **Test**: Script injection attempts
  - **Command**: `figma_create_sticky({ text: "<script>alert('xss')</script>" })`
  - **Expected**: Text sanitized, no script execution
  - **Actual**: ________________
- [ ] **Test**: Path traversal attempts
  - **Command**: `figma_create_frame({ name: "../../malicious" })`
  - **Expected**: Name sanitized to safe characters
  - **Actual**: ________________
- [ ] **Test**: Excessive resource requests
  - **Command**: Create frame with 50000x50000 dimensions
  - **Expected**: Request blocked or dimensions clamped
  - **Actual**: ________________

### 2. Network Security
- [ ] **Test**: WebSocket connection security
  - **Check**: Connection only accepts localhost origins
  - **Expected**: External connections rejected
  - **Actual**: ________________
- [ ] **Test**: Command authorization
  - **Check**: All commands properly validated before execution
  - **Expected**: Invalid commands rejected with errors
  - **Actual**: ________________

## Integration Testing

### 1. Claude Code CLI Integration
- [ ] **Test**: MCP tools available in Claude
  - **Command**: Ask Claude to list Figma tools
  - **Expected**: All figma_* tools listed and callable
  - **Actual**: ________________
- [ ] **Test**: Natural language to Figma operations
  - **Command**: "Create a blue sticky note saying 'Design Review'"
  - **Expected**: Claude uses figma_create_sticky appropriately
  - **Actual**: ________________
- [ ] **Test**: Dashboard generation from description
  - **Command**: "Create a 3-column dashboard for sales metrics"
  - **Expected**: Appropriate dashboard layout created
  - **Actual**: ________________

### 2. Usage Analytics
- [ ] **Test**: Usage logging functionality
  - **Action**: Perform various operations
  - **Expected**: Usage logs sent to MCP Hub for Supabase storage
  - **Actual**: ________________
- [ ] **Test**: Component tracking
  - **Action**: Create and place components
  - **Expected**: Component usage tracked with metadata
  - **Actual**: ________________

## User Experience Testing

### 1. Plugin UI/UX
- [ ] **Test**: Connection status clarity
  - **Check**: Status messages are clear and actionable
  - **Rating**: Clear / Unclear / Confusing
  - **Notes**: ________________
- [ ] **Test**: Error message helpfulness
  - **Check**: Errors provide actionable guidance
  - **Rating**: Helpful / Adequate / Confusing
  - **Notes**: ________________

### 2. Workflow Integration
- [ ] **Test**: Figma workflow disruption
  - **Check**: Plugin doesn't interfere with normal Figma use
  - **Rating**: Seamless / Minor issues / Disruptive
  - **Notes**: ________________
- [ ] **Test**: Command feedback
  - **Check**: Users receive clear confirmation of actions
  - **Rating**: Clear / Adequate / Confusing
  - **Notes**: ________________

## Compatibility Testing

### 1. Figma Versions
- [ ] **Test**: Figma Desktop (current version)
  - **Version**: ________________
  - **Status**: Pass / Fail / Issues
  - **Notes**: ________________
- [ ] **Test**: Figma Beta (if available)
  - **Version**: ________________
  - **Status**: Pass / Fail / Issues
  - **Notes**: ________________

### 2. Operating Systems
- [ ] **Test**: macOS
  - **Version**: ________________
  - **Status**: Pass / Fail / Issues
  - **Notes**: ________________
- [ ] **Test**: Windows (if applicable)
  - **Version**: ________________
  - **Status**: Pass / Fail / Issues
  - **Notes**: ________________
- [ ] **Test**: Linux (if applicable)
  - **Version**: ________________
  - **Status**: Pass / Fail / Issues
  - **Notes**: ________________

## Acceptance Criteria

### Must Have (Blocking Issues)
- [ ] All core commands execute successfully
- [ ] WebSocket connection is stable and reliable
- [ ] No security vulnerabilities identified
- [ ] Error handling is robust and user-friendly
- [ ] Performance meets target metrics

### Nice to Have (Enhancement Opportunities)
- [ ] Advanced dashboard templates work perfectly
- [ ] Brand token application is comprehensive
- [ ] Usage analytics provide valuable insights
- [ ] Plugin UI is polished and intuitive

## Sign-off

### Technical Validation
- **Developer**: ________________ Date: ________
- **QA Lead**: ________________ Date: ________

### User Acceptance  
- **Design Lead**: ________________ Date: ________
- **Product Owner**: ________________ Date: ________

### Security Review
- **Security Reviewer**: ________________ Date: ________

## Notes & Issues

### Issues Identified
1. ________________
2. ________________
3. ________________

### Recommendations
1. ________________
2. ________________
3. ________________

### Follow-up Actions
- [ ] Issue #1: ________________
- [ ] Issue #2: ________________
- [ ] Issue #3: ________________