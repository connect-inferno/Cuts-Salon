import { Router } from 'express';
import { ExpenseController } from '../controllers/expense.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate, requireRole(['OWNER']));
router.post('/', ExpenseController.create);
router.get('/', ExpenseController.list);
router.patch('/:id', ExpenseController.update);

export default router;
