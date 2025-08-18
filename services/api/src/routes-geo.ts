import { Router } from 'express';
import * as turf from '@turf/turf';
import { Pool } from 'pg';

const router = Router();
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// GET /geo/contains?lat=<>&lon=<>&level=<>
router.get('/geo/contains', async (req, res) => {
  try {
    const { lat, lon, level } = req.query;
    
    if (!lat || !lon) {
      return res.status(400).json({ error: 'lat and lon are required' });
    }
    
    const latitude = parseFloat(lat as string);
    const longitude = parseFloat(lon as string);
    
    // Get boundary candidates from DB
    const result = await pool.query(
      'SELECT * FROM geo.find_candidates($1, $2, $3)',
      [longitude, latitude, level || null]
    );
    
    if (result.rows.length === 0) {
      return res.json({ 
        found: false,
        point: [longitude, latitude],
        level: level || 'any'
      });
    }
    
    // Check each candidate with exact point-in-polygon
    const point = turf.point([longitude, latitude]);
    
    for (const candidate of result.rows) {
      const geometry = candidate.feature.geometry;
      
      if (geometry.type === 'Polygon' || geometry.type === 'MultiPolygon') {
        const polygon = turf.feature(geometry);
        
        if (turf.booleanPointInPolygon(point, polygon)) {
          return res.json({
            found: true,
            boundary: {
              id: candidate.id,
              level: candidate.level,
              code: candidate.code,
              name: candidate.name,
              properties: candidate.feature.properties
            },
            point: [longitude, latitude]
          });
        }
      }
    }
    
    // No match found
    return res.json({ 
      found: false,
      point: [longitude, latitude],
      level: level || 'any',
      candidates_checked: result.rows.length
    });
    
  } catch (error) {
    console.error('Geo contains error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;