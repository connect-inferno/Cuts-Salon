import { Router } from 'express';
import { DiscountRequestController } from '../controllers/discountRequest.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.post('/', DiscountRequestController.create);
router.get('/', DiscountRequestController.list);
router.patch('/:id/approve', requireRole(['OWNER']), DiscountRequestController.approve);
router.patch('/:id/reject', requireRole(['OWNER']), DiscountRequestController.reject);

export default router;
