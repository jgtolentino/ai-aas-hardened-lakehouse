# Superset configuration additions for choropleth support
# Add these lines to your main superset_config.py file

import os
from typing import Optional

# =============================================================================
# Mapbox Configuration for Choropleth Maps
# =============================================================================

# Get Mapbox API key from environment variable ONLY (no hardcoded fallback)
MAPBOX_API_KEY = os.environ.get("MAPBOX_API_KEY", "")

# Mapbox style URL - can be customized per deployment
MAPBOX_STYLE_URL = os.environ.get("MAPBOX_STYLE_URL", "mapbox://styles/mapbox/light-v10")

# =============================================================================
# Feature Flags for Geospatial Visualizations
# =============================================================================

# Enable Deck.gl visualizations (required for choropleth)
FEATURE_FLAGS = {
    **FEATURE_FLAGS,  # Preserve existing feature flags
    "ENABLE_DECK_GL_VISUALIZATIONS": True,
    "ENABLE_GEOSPATIAL_VISUALIZATIONS": True,
    "ENABLE_JAVASCRIPT_CONTROLS": True,  # For custom JS in visualizations
}

# =============================================================================
# Map Tile Caching Configuration
# =============================================================================

# Cache map tiles to improve performance
MAP_TILE_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,  # 24 hours
    "CACHE_KEY_PREFIX": "superset_map_tiles",
    "CACHE_REDIS_URL": os.environ.get("REDIS_URL", "redis://localhost:6379/2"),
}

# =============================================================================
# Default Map Settings for Philippines
# =============================================================================

# Default viewport centered on Philippines
DEFAULT_LONGITUDE = 122.0
DEFAULT_LATITUDE = 12.5
DEFAULT_ZOOM = 5.5

# Map bounds for Philippines (to restrict panning)
MAP_BOUNDS = {
    "west": 116.0,
    "south": 4.5,
    "east": 127.0,
    "north": 21.5,
}

# =============================================================================
# PostGIS Database Configuration
# =============================================================================

# Ensure PostGIS types are recognized
from sqlalchemy.dialects.postgresql import GEOGRAPHY, GEOMETRY

# Register custom types for spatial columns
CUSTOM_TYPES = {
    "GEOGRAPHY": GEOGRAPHY,
    "GEOMETRY": GEOMETRY,
}

# =============================================================================
# Performance Settings for Large Geometries
# =============================================================================

# Limit the size of geometry data that can be loaded
MAX_GEOMETRY_SIZE_MB = 50

# Simplification tolerance for client-side rendering
GEOMETRY_SIMPLIFY_TOLERANCE = 0.002

# Maximum number of features to display on a single map
MAX_MAP_FEATURES = 10000

# =============================================================================
# Security Settings for Map Data
# =============================================================================

# Restrict map data access based on user roles
MAP_DATA_ACCESS_ROLES = ["Admin", "Alpha", "Gamma", "Scout_Analyst"]

# Enable row-level security for geographic data
ENABLE_GEO_RLS = True

# =============================================================================
# Logging for Map Performance
# =============================================================================

# Log slow map queries
LOG_SLOW_MAP_QUERIES = True
SLOW_MAP_QUERY_THRESHOLD_MS = 3000

# =============================================================================
# Custom CSS for Map Controls
# =============================================================================

# Add custom CSS for better map controls
CUSTOM_CSS = """
/* Choropleth legend styling */
.deck-gl-legend {
    background: rgba(255, 255, 255, 0.9);
    padding: 10px;
    border-radius: 4px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

/* Map control buttons */
.mapboxgl-ctrl-group {
    background: rgba(255, 255, 255, 0.95);
}

/* Tooltip styling */
.deck-gl-tooltip {
    max-width: 300px;
    font-size: 12px;
    line-height: 1.4;
}
"""

# =============================================================================
# Environment-Specific Instructions
# =============================================================================

print("""
================================================================================
MAPBOX CONFIGURATION INSTRUCTIONS
================================================================================

To enable Mapbox base maps for choropleth visualizations:

1. Sign up for a free Mapbox account at https://www.mapbox.com/

2. Create an access token with the following scopes:
   - styles:read (for accessing map styles)
   - fonts:read (for map labels)
   - datasets:read (optional, for custom datasets)

3. Set the environment variable before starting Superset:
   
   export MAPBOX_API_KEY="pk.your_actual_mapbox_token_here"
   
   Or add to your docker-compose.yml:
   
   environment:
     - MAPBOX_API_KEY=pk.your_actual_mapbox_token_here

4. Restart Superset to apply the configuration

5. Optional: Create a custom map style at https://studio.mapbox.com/
   and update MAPBOX_STYLE_URL

================================================================================
""")