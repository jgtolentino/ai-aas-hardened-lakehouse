# Mapbox configuration for Superset choropleth maps
# This file is for DOCUMENTATION ONLY - do not use in production
# The actual key must be injected via environment variables from K8s secrets

# Mapbox API key for base map tiles
# Sign up at https://www.mapbox.com/ to get a free API key
# MAPBOX_API_KEY = "pk.your_mapbox_api_key_here"  # DO NOT HARDCODE - USE ENV VAR

# Optional: Custom Mapbox style URL
# Default styles:
# - mapbox://styles/mapbox/light-v10 (light theme)
# - mapbox://styles/mapbox/dark-v10 (dark theme)
# - mapbox://styles/mapbox/streets-v11 (street map)
# - mapbox://styles/mapbox/satellite-v9 (satellite imagery)
MAPBOX_STYLE_URL = "mapbox://styles/mapbox/light-v10"

# Feature flags for map visualizations
FEATURE_FLAGS = {
    "ENABLE_DECK_GL_VISUALIZATIONS": True,
    "ENABLE_GEOSPATIAL_VISUALIZATIONS": True,
}

# Map tile cache settings (optional)
MAP_TILE_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,  # 24 hours
    "CACHE_KEY_PREFIX": "superset_map_tiles",
}

# Default map viewport for Philippines
DEFAULT_MAP_VIEWPORT = {
    "longitude": 122.0,
    "latitude": 12.5,
    "zoom": 5.5,
    "bearing": 0,
    "pitch": 0,
}