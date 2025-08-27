# Mapbox MCP Server — Integration

## Prereqs
1) Mapbox account with API access
2) Public access token (pk.*) for map rendering
3) Secret access token (sk.*) for server-side operations (optional)

## Configuration
- **Access Token**: pk.eyJ1... (public token for client-side maps)
- **Style URLs**: Standard Mapbox styles or custom styles
- **Port**: Typically runs on localhost with SSE transport

## Tools Available
- Map rendering and styling
- Geocoding and reverse geocoding
- Directions and routing
- Spatial analysis
- Data visualization layers

## Integration with Figma
- Generate map components from Figma designs
- Sync map styles with design system
- Create location-aware UI components
- Generate geospatial data visualizations

## Security Notes
- Use public tokens for client-side operations
- Keep secret tokens secure for server-side operations
- Never commit tokens to version control
- Use environment variables for configuration
