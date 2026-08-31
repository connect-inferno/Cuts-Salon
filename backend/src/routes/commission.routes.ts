import { Router } from 'express';
import { CommissionController } from '../controllers/commission.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.get('/', CommissionController.list);
router.patch('/:id/pay', requireRole(['OWNER']), CommissionController.markPaid);

export default router;
