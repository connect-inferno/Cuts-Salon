import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import authRoutes from './routes/auth.routes';
import onboardingRoutes from './routes/onboarding.routes';
import customerRoutes from './routes/customer.routes';
import employeeRoutes from './routes/employee.routes';
import billRoutes from './routes/bill.routes';

dotenv.config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

// Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/onboarding', onboardingRoutes);
app.use('/api/v1/customers', customerRoutes);
app.use('/api/v1/employees', employeeRoutes);
app.use('/api/v1/bills', billRoutes);

// Root Welcome Endpoint
app.get('/', (req, res) => {
  res.status(200).json({
    message: 'Salon Business Management System API is running',
    version: '1.0.0',
    documentation: '/health'
  });
});

// Health Check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date() });
});

// Global Error Handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: err.message || 'Internal Server Error' });
});

export default app;
