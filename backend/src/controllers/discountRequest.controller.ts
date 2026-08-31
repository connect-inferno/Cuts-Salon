import { Response } from 'express';
import { z } from 'zod';
import { DiscountRequestService } from '../services/discountRequest.service';
import { AuthRequest } from '../middleware/auth.middleware';

const createSchema = z.object({
  billId: z.string().uuid().optional(),
  requestedDiscount: z.number().nonnegative(),
  overridePrice: z.number().nonnegative().optional(),
  reason: z.string().min(1, 'Reason is required'),
});

export class DiscountRequestController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const parsed = createSchema.parse(req.body);
      const result = await DiscountRequestService.create(req.user!.salonId, req.user!.userId, parsed);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create discount request' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const status = typeof req.query.status === 'string' ? (req.query.status as any) : undefined;
      const result = await DiscountRequestService.list(req.user!.salonId, req.user!, status);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list discount requests' });
    }
  }

  static async approve(req: AuthRequest, res: Response) {
    try {
      const result = await DiscountRequestService.approve(req.user!.salonId, req.params.id, req.user!.userId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to approve discount request' });
    }
  }

  static async reject(req: AuthRequest, res: Response) {
    try {
      const result = await DiscountRequestService.reject(req.user!.salonId, req.params.id, req.user!.userId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to reject discount request' });
    }
  }
}
