import { Router } from 'express';
import { CustomerController } from '../controllers/customer.controller';
import { authenticate } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.post('/', CustomerController.create);
router.get('/', CustomerController.list);
router.get('/:id', CustomerController.getById);
router.patch('/:id', CustomerController.update);

export default router;
