import { Router } from 'express';
import { ServiceCategoryController } from '../controllers/serviceCategory.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.get('/', ServiceCategoryController.list);
router.post('/', requireRole(['OWNER']), ServiceCategoryController.create);
router.patch('/:id', requireRole(['OWNER']), ServiceCategoryController.update);

export default router;
