import { Router } from 'express';
import { BranchController } from '../controllers/branch.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.get('/', BranchController.list);
router.get('/:id', BranchController.getById);
router.post('/', requireRole(['OWNER']), BranchController.create);
router.patch('/:id', requireRole(['OWNER']), BranchController.update);

export default router;
