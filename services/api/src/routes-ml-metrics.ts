import { Router } from 'express';
import { Pool } from 'pg';

const router = Router();
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// GET /ml/metrics?model_name=&model_version=
router.get('/ml/metrics', async (req, res) => {
  try {
    const { model_name, model_version } = req.query;
    
    let query = `
      SELECT 
        model_name,
        model_version,
        day,
        prediction_count,
        labeled_count,
        accuracy,
        ece,
        mce,
        confidence_mean,
        confidence_std,
        confidence_p10,
        confidence_p50,
        confidence_p90,
        class_distribution
      FROM ml.metrics_daily
      WHERE day >= CURRENT_DATE - INTERVAL '30 days'
    `;
    
    const params: any[] = [];
    const conditions: string[] = [];
    
    if (model_name) {
      params.push(model_name);
      conditions.push(`model_name = $${params.length}`);
    }
    
    if (model_version) {
      params.push(model_version);
      conditions.push(`model_version = $${params.length}`);
    }
    
    if (conditions.length > 0) {
      query += ' AND ' + conditions.join(' AND ');
    }
    
    query += ' ORDER BY day DESC';
    
    const result = await pool.query(query, params);
    
    // Also get current ECE from view
    let eceQuery = 'SELECT * FROM ml.v_ece_window';
    if (conditions.length > 0) {
      eceQuery += ' WHERE ' + conditions.join(' AND ');
    }
    
    const eceResult = await pool.query(eceQuery, params);
    
    res.json({
      metrics: result.rows,
      current_ece: eceResult.rows[0] || null,
      period: '30 days'
    });
    
  } catch (error) {
    console.error('ML metrics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;