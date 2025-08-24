import { Router } from 'express';
import { Pool } from 'pg';

const router = Router();
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// GET /api/ml/metrics/daily
router.get('/ml/metrics/daily', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        model_name,
        COALESCE(accuracy, 0) as accuracy,
        COALESCE(ece, 0) as ece,
        COALESCE(predictions_today, 0) as predictions_count
      FROM ml.v_daily_metrics
      WHERE metric_date = CURRENT_DATE
      ORDER BY model_name
    `);
    
    res.json({
      metrics: result.rows,
      date: new Date().toISOString()
    });
  } catch (error) {
    console.error('ML metrics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/transactions/recent-confidences
router.get('/transactions/recent-confidences', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 50;
    
    const result = await pool.query(`
      SELECT 
        transaction_id,
        top_brand,
        confidence_final::numeric as confidence_final,
        top_brand_items as items_analyzed
      FROM ml.v_tx_brand_confidence
      WHERE prediction_timestamp >= NOW() - INTERVAL '24 hours'
      ORDER BY prediction_timestamp DESC
      LIMIT $1
    `, [limit]);
    
    res.json({
      transactions: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Transaction confidence error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/srp/catalog
router.get('/srp/catalog', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 100;
    
    const result = await pool.query(`
      SELECT 
        brand,
        product,
        srp::numeric as srp,
        effective_date as last_updated
      FROM reference.v_latest_srp
      ORDER BY brand, product
      LIMIT $1
    `, [limit]);
    
    res.json({
      prices: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('SRP catalog error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/system/health
router.get('/system/health', async (req, res) => {
  try {
    const checks = await Promise.all([
      pool.query('SELECT COUNT(*) FROM ml.prediction_events WHERE prediction_timestamp >= NOW() - INTERVAL \'1 hour\''),
      pool.query('SELECT COUNT(*) FROM reference.srp_prices'),
      pool.query('SELECT COUNT(*) FROM geo.boundaries'),
      pool.query('SELECT COUNT(*) FROM dw.fact_transactions')
    ]);
    
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      metrics: {
        recent_predictions: parseInt(checks[0].rows[0].count),
        srp_entries: parseInt(checks[1].rows[0].count),
        geo_boundaries: parseInt(checks[2].rows[0].count),
        dw_transactions: parseInt(checks[3].rows[0].count)
      }
    });
  } catch (error) {
    console.error('Health check error:', error);
    res.status(503).json({ 
      status: 'unhealthy',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

export default router;