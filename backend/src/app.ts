import express from 'express';
import cors from 'cors';
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
