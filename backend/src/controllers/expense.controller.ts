import { Response } from 'express';
import { z } from 'zod';
import { ExpenseService } from '../services/expense.service';
import { AuthRequest } from '../middleware/auth.middleware';

const categoryEnum = z.enum(['RENT', 'UTILITIES', 'SUPPLIES', 'WAGES', 'MISC']);

const createExpenseSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  amount: z.number().positive(),
  category: categoryEnum,
  date: z.string(),
  receiptUrl: z.string().url().optional(),
  notes: z.string().optional(),
});

const updateExpenseSchema = createExpenseSchema.partial();

export class ExpenseController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const parsed = createExpenseSchema.parse(req.body);
      const result = await ExpenseService.create(req.user!.salonId, req.user!.userId, parsed);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create expense' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const from = typeof req.query.from === 'string' ? req.query.from : undefined;
      const to = typeof req.query.to === 'string' ? req.query.to : undefined;
      const result = await ExpenseService.list(req.user!.salonId, from, to);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list expenses' });
    }
  }

  static async update(req: AuthRequest, res: Response) {
    try {
      const parsed = updateExpenseSchema.parse(req.body);
      const result = await ExpenseService.update(req.user!.salonId, req.params.id, parsed);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to update expense' });
    }
  }
}
