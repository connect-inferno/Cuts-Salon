import { Response } from 'express';
import { z } from 'zod';
import { CustomerService } from '../services/customer.service';
import { AuthRequest } from '../middleware/auth.middleware';

const customerSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  phone: z.string().min(6, 'Valid phone number is required'),
  email: z.string().email().optional(),
  gender: z.string().optional(),
  dob: z.string().optional(),
  notes: z.string().optional(),
  isVip: z.boolean().optional(),
  branchId: z.string().uuid('Invalid branch id'),
});

const customerUpdateSchema = customerSchema.partial();

export class CustomerController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const parsed = customerSchema.parse(req.body);
      const result = await CustomerService.create(req.user!.salonId, parsed);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create customer' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const search = typeof req.query.search === 'string' ? req.query.search : undefined;
      const branchId = typeof req.query.branchId === 'string' ? req.query.branchId : undefined;
      const result = await CustomerService.list(req.user!.salonId, search, branchId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list customers' });
    }
  }

  static async getById(req: AuthRequest, res: Response) {
    try {
      const result = await CustomerService.getById(req.user!.salonId, req.params.id);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(404).json({ error: error.message || 'Customer not found' });
    }
  }

  static async update(req: AuthRequest, res: Response) {
    try {
      const parsed = customerUpdateSchema.parse(req.body);
      const result = await CustomerService.update(req.user!.salonId, req.params.id, parsed);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to update customer' });
    }
  }
}
