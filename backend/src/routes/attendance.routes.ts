import { Router } from 'express';
import { AttendanceController } from '../controllers/attendance.controller';
import { authenticate, requireRole } from '../middleware/auth.middleware';

const router = Router();

router.use(authenticate);
router.post('/clock-in', AttendanceController.clockIn);
router.post('/clock-out', AttendanceController.clockOut);
router.get('/', AttendanceController.list);
router.post('/mark', requireRole(['OWNER']), AttendanceController.mark);

export default router;
