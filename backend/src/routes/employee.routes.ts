import { Router } from 'express';
import { EmployeeController } from '../controllers/employee.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate, requireRole(['OWNER']));
router.post('/', EmployeeController.create);
router.get('/', EmployeeController.list);
router.patch('/:id', EmployeeController.update);
router.patch('/:id/reset-password', EmployeeController.resetPassword);

export default router;
