import { Router } from 'express';
import { SalaryController } from '../controllers/salary.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.get('/', SalaryController.list);
router.post('/generate', requireRole(['OWNER']), SalaryController.generate);
router.patch('/:id/pay', requireRole(['OWNER']), SalaryController.markPaid);

export default router;
