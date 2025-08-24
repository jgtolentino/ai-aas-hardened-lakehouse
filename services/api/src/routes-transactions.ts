import { Router } from 'express';
import { Pool } from 'pg';

const router = Router();
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// GET /transactions/:id/confidence
router.get('/transactions/:id/confidence', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pool.query(
      'SELECT * FROM ml.v_tx_brand_confidence WHERE transaction_id = $1',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.json({ 
        found: false,
        transaction_id: id,
        message: 'No predictions found for this transaction'
      });
    }
    
    const confidence = result.rows[0];
    return res.json({
      found: true,
      transaction_id: confidence.transaction_id,
      top_brand: confidence.top_brand,
      base_confidence: parseFloat(confidence.base_confidence),
      agreement: parseFloat(confidence.agreement),
      confidence_final: parseFloat(confidence.confidence_final),
      items_analyzed: confidence.top_brand_items,
      total_items: confidence.total_items
    });
    
  } catch (error) {
    console.error('Transaction confidence error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /transactions/:id/predictions
router.get('/transactions/:id/predictions', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pool.query(
      `SELECT 
        item_product_id,
        item_sku_id,
        predicted_brand,
        raw_confidence,
        calibrated_confidence,
        model_name,
        model_version,
        prediction_timestamp
      FROM ml.v_tx_item_predictions 
      WHERE transaction_id = $1
      ORDER BY calibrated_confidence DESC`,
      [id]
    );
    
    res.json({
      transaction_id: id,
      predictions: result.rows.map(row => ({
        item_product_id: row.item_product_id,
        item_sku_id: row.item_sku_id,
        predicted_brand: row.predicted_brand,
        confidence: {
          raw: parseFloat(row.raw_confidence),
          calibrated: parseFloat(row.calibrated_confidence)
        },
        model: {
          name: row.model_name,
          version: row.model_version
        },
        timestamp: row.prediction_timestamp
      })),
      count: result.rows.length
    });
    
  } catch (error) {
    console.error('Transaction predictions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;