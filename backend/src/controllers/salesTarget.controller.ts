import { Response } from 'express';
import { z } from 'zod';
import { SalesTargetService } from '../services/salesTarget.service';
import { AuthRequest } from '../middleware/auth.middleware';

const createTargetSchema = z.object({
  employeeId: z.string().uuid(),
  type: z.enum(['SERVICE_VOLUME', 'PRODUCT_SALES_COUNT']),
  targetValue: z.number().positive(),
  startDate: z.string(),
  endDate: z.string(),
});

const updateTargetSchema = z.object({
  targetValue: z.number().positive().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});

export class SalesTargetController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const parsed = createTargetSchema.parse(req.body);
      const result = await SalesTargetService.create(req.user!.salonId, parsed);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create sales target' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const employeeId = typeof req.query.employeeId === 'string' ? req.query.employeeId : undefined;
      const result = await SalesTargetService.list(req.user!.salonId, req.user!, employeeId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list sales targets' });
    }
  }

  static async update(req: AuthRequest, res: Response) {
    try {
      const parsed = updateTargetSchema.parse(req.body);
      const result = await SalesTargetService.update(req.user!.salonId, req.params.id, parsed);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to update sales target' });
    }
  }
}
