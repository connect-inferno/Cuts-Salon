import { Router } from 'express';
import { ServiceController } from '../controllers/service.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.get('/', ServiceController.list);
router.get('/:id', ServiceController.getById);
router.post('/', requireRole(['OWNER']), ServiceController.create);
router.patch('/:id', requireRole(['OWNER']), ServiceController.update);

export default router;
