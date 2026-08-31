import { Response } from 'express';
import { DashboardService } from '../services/dashboard.service';
import { AuthRequest } from '../middleware/auth.middleware';

export class DashboardController {
  static async summary(req: AuthRequest, res: Response) {
    try {
      const result = await DashboardService.summary(req.user!.salonId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to load dashboard summary' });
    }
  }
}
