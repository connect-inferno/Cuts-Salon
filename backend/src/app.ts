import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import path from 'path';
import authRoutes from './routes/auth.routes';
import onboardingRoutes from './routes/onboarding.routes';
import customerRoutes from './routes/customer.routes';
import employeeRoutes from './routes/employee.routes';
import billRoutes from './routes/bill.routes';
import serviceCategoryRoutes from './routes/serviceCategory.routes';
import serviceRoutes from './routes/service.routes';
import inventoryRoutes from './routes/inventory.routes';
import settingsRoutes from './routes/settings.routes';
import attendanceRoutes from './routes/attendance.routes';
import salesTargetRoutes from './routes/salesTarget.routes';
import expenseRoutes from './routes/expense.routes';
import discountRequestRoutes from './routes/discountRequest.routes';
import salaryRoutes from './routes/salary.routes';
import commissionRoutes from './routes/commission.routes';
import dashboardRoutes from './routes/dashboard.routes';
import branchRoutes from './routes/branch.routes';

dotenv.config();

const app = express();

// Render sits behind a reverse proxy - without this, express-rate-limit
// sees every request as coming from the same proxy IP.
app.set('trust proxy', 1);

// Locked down once CORS_ORIGINS is set (comma-separated) on the host - until
// then this stays open so nothing breaks for whatever's already deployed.
const corsOrigins = process.env.CORS_ORIGINS?.split(',').map((o) => o.trim()).filter(Boolean);
app.use(cors({ origin: corsOrigins && corsOrigins.length > 0 ? corsOrigins : true }));

// Login is the brute-force/credential-stuffing target; keep it tight.
// Everything else gets a much looser ceiling just to blunt abuse/scraping.
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts. Please try again in a few minutes.' },
});
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests. Please slow down.' },
});
app.use('/api/v1/auth/login', loginLimiter);
app.use('/api/v1', apiLimiter);

app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

// Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/onboarding', onboardingRoutes);
app.use('/api/v1/customers', customerRoutes);
app.use('/api/v1/employees', employeeRoutes);
app.use('/api/v1/bills', billRoutes);
app.use('/api/v1/service-categories', serviceCategoryRoutes);
app.use('/api/v1/services', serviceRoutes);
app.use('/api/v1/inventory', inventoryRoutes);
app.use('/api/v1/settings', settingsRoutes);
app.use('/api/v1/attendance', attendanceRoutes);
app.use('/api/v1/sales-targets', salesTargetRoutes);
app.use('/api/v1/expenses', expenseRoutes);
app.use('/api/v1/discount-requests', discountRequestRoutes);
app.use('/api/v1/salary', salaryRoutes);
app.use('/api/v1/commissions', commissionRoutes);
app.use('/api/v1/dashboard', dashboardRoutes);
app.use('/api/v1/branches', branchRoutes);

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

// Global Error Handler - every route already catches its own errors and
// returns a clean message, so anything landing here is unexpected. Log the
// real error server-side but never echo err.message to the client - it can
// leak internal details (stack fragments, library/DB error text).
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: 'Internal Server Error' });
});

export default app;
