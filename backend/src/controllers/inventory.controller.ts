import { Response } from 'express';
import { z } from 'zod';
import { InventoryService } from '../services/inventory.service';
import { AuthRequest } from '../middleware/auth.middleware';

const createInventorySchema = z.object({
  sku: z.string().min(1, 'SKU is required'),
  name: z.string().min(1, 'Name is required'),
  category: z.string().min(1, 'Category is required'),
  price: z.number().nonnegative(),
  costPrice: z.number().nonnegative(),
  stockCount: z.number().int().nonnegative().optional(),
  minAlertThreshold: z.number().int().nonnegative().optional(),
});

const updateInventorySchema = createInventorySchema.partial();

export class InventoryController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const parsed = createInventorySchema.parse(req.body);
      const result = await InventoryService.create(req.user!.salonId, parsed);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create inventory item' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const result = await InventoryService.list(req.user!.salonId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list inventory items' });
    }
  }

  static async getById(req: AuthRequest, res: Response) {
    try {
      const result = await InventoryService.getById(req.user!.salonId, req.params.id);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(404).json({ error: error.message || 'Inventory item not found' });
    }
  }

  static async update(req: AuthRequest, res: Response) {
    try {
      const parsed = updateInventorySchema.parse(req.body);
      const result = await InventoryService.update(req.user!.salonId, req.params.id, parsed);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to update inventory item' });
    }
  }
}
