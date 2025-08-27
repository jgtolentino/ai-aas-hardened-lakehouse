# sc:mapbox-connect

**Goal**: Connect to Mapbox MCP server for geospatial operations and map rendering.

**Steps**
1. Ensure Mapbox MCP server is running on port 3847
2. Configure environment variable:
   - `MAPBOX_ACCESS_TOKEN`: Your public access token (pk.eyJ1...)
3. Add MCP server to your client:
   - Name: Mapbox MCP
   - URL: http://127.0.0.1:3847/sse

**Tools Available**
- Map rendering and styling
- Geocoding and reverse geocoding
- Directions and routing
- Spatial analysis
- Data visualization layers

**Integration with Figma**
- Generate map components from designs
- Sync map styles with design system
- Create location-aware UI components

**Security**: Use public tokens for client-side operations. Never commit tokens to version control.
