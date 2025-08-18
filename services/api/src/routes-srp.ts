import { Router } from 'express';
import { Pool } from 'pg';

const router = Router();
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// GET /srp?gtin=... | product_id=... | brand_id=...
router.get('/srp', async (req, res) => {
  try {
    const { gtin, product_id, brand_id } = req.query;
    
    if (!gtin && !product_id && !brand_id) {
      return res.status(400).json({ 
        error: 'At least one of gtin, product_id, or brand_id is required' 
      });
    }
    
    // Call the SRP lookup function
    const result = await pool.query(
      'SELECT * FROM scout.lookup_srp($1, $2, $3)',
      [
        gtin || null,
        product_id ? parseInt(product_id as string) : null,
        brand_id ? parseInt(brand_id as string) : null
      ]
    );
    
    if (result.rows.length === 0) {
      return res.json({ 
        found: false,
        query: { gtin, product_id, brand_id }
      });
    }
    
    const srp = result.rows[0];
    return res.json({
      found: true,
      srp: parseFloat(srp.srp),
      currency: srp.currency,
      source: srp.source,
      effective_date: srp.effective_date,
      confidence: parseFloat(srp.confidence),
      query: { gtin, product_id, brand_id }
    });
    
  } catch (error) {
    console.error('SRP lookup error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;