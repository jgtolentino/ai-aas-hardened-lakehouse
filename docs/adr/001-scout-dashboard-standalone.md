# ADR-001: Scout Analytics Dashboard Standalone Repository

## Status
**ACCEPTED** - Implemented on August 27, 2025

## Context
The Scout Analytics Dashboard was previously managed as a Git submodule at `modules/scout-analytics-dashboard/` within the `ai-aas-hardened-lakehouse` repository. This created several issues:

1. **Naming Confusion**: Two similar repository names (`scout-analytics-dashboard` vs `scout-analytics-blueprint-doc`) caused developer confusion
2. **Complex Workflow**: Submodule management added unnecessary complexity for a standalone UI component
3. **Development Friction**: Developers had to navigate submodule workflows for simple UI changes
4. **Repository Clarity**: The main repository contained mixed concerns (platform + UI)

## Decision
We have decided to **remove the Scout Analytics Dashboard as a submodule** and establish [`scout-analytics-blueprint-doc`](https://github.com/jgtolentino/scout-analytics-blueprint-doc.git) as the **canonical standalone repository** for the Scout Dashboard UI.

## Consequences

### Positive
- **Simplified Development**: Direct development in standalone repository eliminates submodule complexity
- **Clear Separation**: Clean separation between platform infrastructure and UI components
- **Faster Iteration**: No submodule pointer updates required for UI changes
- **Eliminated Confusion**: Single source of truth for Scout Dashboard development
- **Independent Versioning**: UI can be versioned and released independently

### Negative  
- **Integration Complexity**: Platform integration requires explicit coordination
- **Deployment Coordination**: Separate deployment pipelines needed for UI and backend
- **Documentation Updates**: All references to the submodule need updating

## Implementation
1. ✅ Removed `modules/scout-analytics-dashboard/` directory
2. ✅ Cleaned up git submodule configuration
3. ✅ Updated `SUBMODULES_GUIDE.md` documentation  
4. ✅ Created this ADR for future reference

## Alternative Considered
**Keep as Submodule**: Maintain the current submodule structure but improve documentation. 
- Rejected because it doesn't address the root cause of naming confusion and workflow complexity.

## Migration Path
Developers should now:
1. Clone `scout-analytics-blueprint-doc` directly for UI development
2. Use the main repository (`ai-aas-hardened-lakehouse`) for platform/backend work
3. Coordinate deployments between the two repositories as needed

## References
- [Scout Analytics Blueprint Doc Repository](https://github.com/jgtolentino/scout-analytics-blueprint-doc.git)
- [Updated Submodules Guide](../SUBMODULES_GUIDE.md)
- [Platform Integration Documentation](../platform/scout/README.md)

---
**Author**: Claude AI Assistant  
**Date**: August 27, 2025  
**Reviewers**: Enterprise Architecture Team  
**Next Review**: September 15, 2025