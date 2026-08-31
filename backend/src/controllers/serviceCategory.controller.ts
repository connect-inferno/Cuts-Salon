import { Response } from 'express';
import { z } from 'zod';
import { ServiceCategoryService } from '../services/serviceCategory.service';
import { AuthRequest } from '../middleware/auth.middleware';

const nameSchema = z.object({ name: z.string().min(1, 'Name is required') });

export class ServiceCategoryController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const { name } = nameSchema.parse(req.body);
      const result = await ServiceCategoryService.create(req.user!.salonId, name);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create category' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const result = await ServiceCategoryService.list(req.user!.salonId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list categories' });
    }
  }

  static async update(req: AuthRequest, res: Response) {
    try {
      const { name } = nameSchema.parse(req.body);
      const result = await ServiceCategoryService.update(req.user!.salonId, req.params.id, name);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to update category' });
    }
  }
}
