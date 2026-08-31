import { Router } from 'express';
import { SettingsController } from '../controllers/settings.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.get('/', SettingsController.get);
router.patch('/', requireRole(['OWNER']), SettingsController.update);

export default router;
