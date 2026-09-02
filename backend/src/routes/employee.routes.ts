import { Router } from 'express';
import { EmployeeController } from '../controllers/employee.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.get('/', EmployeeController.list);
router.post('/', requireRole(['OWNER']), EmployeeController.create);
router.patch('/:id', requireRole(['OWNER']), EmployeeController.update);
router.patch('/:id/reset-password', requireRole(['OWNER']), EmployeeController.resetPassword);

export default router;
