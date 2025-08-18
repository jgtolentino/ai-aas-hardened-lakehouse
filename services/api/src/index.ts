import express from 'express';
import cors from 'cors';
import { Pool } from 'pg';

// Import routes
import geoRoutes from './routes-geo';
import srpRoutes from './routes-srp';
import mlRoutes from './routes-ml-metrics';
import txRoutes from './routes-transactions';

const app = express();
const port = process.env.PORT || 8080;

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'api-gateway' });
});

// Register routes
app.use(geoRoutes);
app.use(srpRoutes);
app.use(mlRoutes);
app.use(txRoutes);

// Error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(port, () => {
  console.log(`API Gateway listening on port ${port}`);
});