import { Response } from 'express';
import { z } from 'zod';
import { BillService } from '../services/bill.service';
import { AuthRequest } from '../middleware/auth.middleware';

const billItemSchema = z.object({
  type: z.enum(['SERVICE', 'PRODUCT']),
  serviceId: z.string().uuid().optional(),
  inventoryItemId: z.string().uuid().optional(),
  employeeId: z.string().uuid(),
  quantity: z.number().int().positive().optional(),
  unitPrice: z.number().nonnegative().optional(),
  priceOverrideReason: z.string().optional(),
  discountAmount: z.number().nonnegative().optional(),
});

const createBillSchema = z.object({
  customerId: z.string().uuid(),
  paymentMethod: z.enum(['CASH', 'CARD', 'UPI']),
  discountAmount: z.number().nonnegative().optional(),
  items: z.array(billItemSchema).min(1, 'At least one item is required'),
});

export class BillController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const parsed = createBillSchema.parse(req.body);
      const result = await BillService.create(req.user!.salonId, req.user!.userId, parsed);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create bill' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const from = typeof req.query.from === 'string' ? req.query.from : undefined;
      const to = typeof req.query.to === 'string' ? req.query.to : undefined;
      const result = await BillService.list(req.user!.salonId, from, to);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list bills' });
    }
  }

  static async getById(req: AuthRequest, res: Response) {
    try {
      const result = await BillService.getById(req.user!.salonId, req.params.id);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(404).json({ error: error.message || 'Bill not found' });
    }
  }
}
