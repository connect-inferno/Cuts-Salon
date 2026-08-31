import { Response } from 'express';
import { z } from 'zod';
import { SalaryService } from '../services/salary.service';
import { AuthRequest } from '../middleware/auth.middleware';

const generateSchema = z.object({
  month: z.number().int().min(1).max(12),
  year: z.number().int().min(2000),
  employeeId: z.string().uuid().optional(),
});

export class SalaryController {
  static async generate(req: AuthRequest, res: Response) {
    try {
      const parsed = generateSchema.parse(req.body);
      const result = await SalaryService.generate(req.user!.salonId, parsed.month, parsed.year, parsed.employeeId);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to generate salary' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const month = typeof req.query.month === 'string' ? Number(req.query.month) : undefined;
      const year = typeof req.query.year === 'string' ? Number(req.query.year) : undefined;
      const employeeId = typeof req.query.employeeId === 'string' ? req.query.employeeId : undefined;
      const result = await SalaryService.list(req.user!.salonId, req.user!, { month, year, employeeId });
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list salary records' });
    }
  }

  static async markPaid(req: AuthRequest, res: Response) {
    try {
      const result = await SalaryService.markPaid(req.user!.salonId, req.params.id);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to mark salary as paid' });
    }
  }
}
