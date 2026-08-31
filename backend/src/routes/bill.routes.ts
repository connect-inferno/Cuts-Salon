import { Router } from 'express';
import { BillController } from '../controllers/bill.controller';
import { authenticate } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.post('/', BillController.create);
router.get('/', BillController.list);
router.get('/:id', BillController.getById);

export default router;
