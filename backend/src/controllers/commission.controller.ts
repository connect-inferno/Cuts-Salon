import { Response } from 'express';
import { CommissionService } from '../services/commission.service';
import { AuthRequest } from '../middleware/auth.middleware';

export class CommissionController {
  static async list(req: AuthRequest, res: Response) {
    try {
      const employeeId = typeof req.query.employeeId === 'string' ? req.query.employeeId : undefined;
      const status = typeof req.query.status === 'string' ? (req.query.status as any) : undefined;
      const result = await CommissionService.list(req.user!.salonId, req.user!, employeeId, status);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list commissions' });
    }
  }

  static async markPaid(req: AuthRequest, res: Response) {
    try {
      const result = await CommissionService.markPaid(req.user!.salonId, req.params.id);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to mark commission as paid' });
    }
  }
}
