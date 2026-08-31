import { Response } from 'express';
import { z } from 'zod';
import { ServiceCatalogService } from '../services/service.service';
import { AuthRequest } from '../middleware/auth.middleware';

const createServiceSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  price: z.number().nonnegative(),
  categoryId: z.string().uuid('Invalid category id'),
});

const updateServiceSchema = createServiceSchema.partial();

export class ServiceController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const parsed = createServiceSchema.parse(req.body);
      const result = await ServiceCatalogService.create(req.user!.salonId, parsed);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create service' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const result = await ServiceCatalogService.list(req.user!.salonId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list services' });
    }
  }

  static async getById(req: AuthRequest, res: Response) {
    try {
      const result = await ServiceCatalogService.getById(req.user!.salonId, req.params.id);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(404).json({ error: error.message || 'Service not found' });
    }
  }

  static async update(req: AuthRequest, res: Response) {
    try {
      const parsed = updateServiceSchema.parse(req.body);
      const result = await ServiceCatalogService.update(req.user!.salonId, req.params.id, parsed);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to update service' });
    }
  }
}
