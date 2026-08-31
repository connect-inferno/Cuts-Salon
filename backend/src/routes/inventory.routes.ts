import { Router } from 'express';
import { InventoryController } from '../controllers/inventory.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.get('/', InventoryController.list);
router.get('/:id', InventoryController.getById);
router.post('/', requireRole(['OWNER']), InventoryController.create);
router.patch('/:id', requireRole(['OWNER']), InventoryController.update);

export default router;
