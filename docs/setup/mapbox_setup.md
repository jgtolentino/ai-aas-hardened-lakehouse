# Mapbox Setup for Scout Analytics Choropleth Maps

This guide walks through setting up Mapbox for the choropleth visualizations in Scout Analytics.

## Prerequisites

- Superset instance running with PostGIS-enabled database
- Geographic boundary data imported (see `geo_boundaries_setup.md`)
- Admin access to Superset

## Step 1: Create a Mapbox Account

1. Go to [https://www.mapbox.com/](https://www.mapbox.com/)
2. Sign up for a free account
3. Verify your email address

## Step 2: Generate an Access Token

1. Log in to your Mapbox account
2. Navigate to Account → Tokens
3. Click "Create a token"
4. Configure the token:
   - **Name**: Scout Analytics Superset
   - **Scopes**:
     - ✅ styles:read
     - ✅ fonts:read
     - ✅ datasets:read (optional)
   - **URL restrictions** (optional): Add your Superset domain
5. Click "Create token"
6. Copy the token (starts with `pk.`)

## Step 3: Configure Superset

### Option A: Environment Variable (Recommended)

Add to your environment or `.env` file:

```bash
export MAPBOX_API_KEY="pk.your_actual_token_here"
```

For Docker Compose, add to `docker-compose.yml`:

```yaml
services:
  superset:
    environment:
      - MAPBOX_API_KEY=pk.your_actual_token_here
```

### Option B: Configuration File

Add to `superset_config.py`:

```python
# Mapbox configuration
MAPBOX_API_KEY = "pk.your_actual_token_here"
```

## Step 4: Restart Superset

```bash
# Docker Compose
docker-compose restart superset

# Kubernetes
kubectl rollout restart deployment/superset

# Local development
pkill -f superset
superset run -p 8088 --with-threads --reload
```

## Step 5: Verify Configuration

1. Open Superset UI
2. Navigate to Charts → Philippines Regional Sales Heatmap
3. The map should display with Mapbox base tiles
4. Check browser console for any Mapbox errors

## Customization Options

### Map Styles

You can use different Mapbox styles:

```python
# Light theme (default)
MAPBOX_STYLE_URL = "mapbox://styles/mapbox/light-v10"

# Dark theme
MAPBOX_STYLE_URL = "mapbox://styles/mapbox/dark-v10"

# Satellite imagery
MAPBOX_STYLE_URL = "mapbox://styles/mapbox/satellite-v9"

# Streets
MAPBOX_STYLE_URL = "mapbox://styles/mapbox/streets-v11"
```

### Custom Map Style

1. Go to [Mapbox Studio](https://studio.mapbox.com/)
2. Create a new style or customize an existing one
3. Publish the style
4. Copy the style URL (e.g., `mapbox://styles/yourusername/styleid`)
5. Update `MAPBOX_STYLE_URL` in configuration

## Troubleshooting

### Map tiles not loading

1. Check browser console for 401/403 errors
2. Verify token is correctly set:
   ```python
   # In Superset SQL Lab
   SELECT current_setting('MAPBOX_API_KEY', true);
   ```
3. Ensure token has required scopes

### Performance issues

1. Enable map tile caching in `superset_config.py`:
   ```python
   MAP_TILE_CACHE_CONFIG = {
       "CACHE_TYPE": "RedisCache",
       "CACHE_DEFAULT_TIMEOUT": 86400,
   }
   ```

2. Use simplified geometries (already configured in our setup)

### CORS errors

If hosting Superset on a custom domain, add domain to Mapbox token restrictions.

## Usage Limits

Free Mapbox account includes:
- 50,000 map loads/month
- 200,000 tile requests/month

For Scout Analytics typical usage:
- ~100 map loads/day = 3,000/month ✅
- ~1,000 tile requests/map load = 100,000/month ✅

Monitor usage at: https://account.mapbox.com/

## Security Best Practices

1. **Use URL restrictions**: Limit token to your Superset domain
2. **Rotate tokens regularly**: Every 90 days
3. **Monitor usage**: Check for unusual activity
4. **Use environment variables**: Don't commit tokens to git

## Integration with Scout Charts

The following charts use Mapbox:
- Philippines Regional Sales Heatmap
- City/Municipality Sales Intensity Map

These charts automatically use the configured Mapbox token for base map tiles.

## Next Steps

1. Test choropleth performance with real data
2. Create custom map styles matching Scout branding
3. Set up monitoring for map usage
4. Configure map-based alerts