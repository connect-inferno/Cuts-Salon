import { Router } from 'express';
import { SalesTargetController } from '../controllers/salesTarget.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.get('/', SalesTargetController.list);
router.post('/', requireRole(['OWNER']), SalesTargetController.create);
router.patch('/:id', requireRole(['OWNER']), SalesTargetController.update);

export default router;
