import { Response } from 'express';
import { z } from 'zod';
import { BranchService } from '../services/branch.service';
import { AuthRequest } from '../middleware/auth.middleware';

const createBranchSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  address: z.string().optional(),
  phone: z.string().optional(),
});

const updateBranchSchema = z.object({
  name: z.string().min(1).optional(),
  address: z.string().optional(),
  phone: z.string().optional(),
  managerId: z.string().uuid().nullable().optional(),
  active: z.boolean().optional(),
});

export class BranchController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const parsed = createBranchSchema.parse(req.body);
      const result = await BranchService.create(req.user!.salonId, parsed);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create branch' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const result = await BranchService.list(req.user!.salonId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list branches' });
    }
  }

  static async getById(req: AuthRequest, res: Response) {
    try {
      const result = await BranchService.getById(req.user!.salonId, req.params.id);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(404).json({ error: error.message || 'Branch not found' });
    }
  }

  static async update(req: AuthRequest, res: Response) {
    try {
      const parsed = updateBranchSchema.parse(req.body);
      const result = await BranchService.update(req.user!.salonId, req.params.id, parsed);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to update branch' });
    }
  }
}
