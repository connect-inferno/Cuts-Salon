import { Response } from 'express';
import { z } from 'zod';
import { EmployeeService } from '../services/employee.service';
import { AuthRequest } from '../middleware/auth.middleware';

const createEmployeeSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  phone: z.string().min(6, 'Valid phone number is required'),
  roleTitle: z.string().min(1, 'Role title is required'),
  baseSalary: z.number().nonnegative(),
  serviceCommissionPct: z.number().min(0).max(100),
  productCommissionPct: z.number().min(0).max(100),
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

const updateEmployeeSchema = z.object({
  name: z.string().min(1).optional(),
  phone: z.string().min(6).optional(),
  roleTitle: z.string().min(1).optional(),
  baseSalary: z.number().nonnegative().optional(),
  serviceCommissionPct: z.number().min(0).max(100).optional(),
  productCommissionPct: z.number().min(0).max(100).optional(),
  active: z.boolean().optional(),
});

export class EmployeeController {
  static async create(req: AuthRequest, res: Response) {
    try {
      const parsed = createEmployeeSchema.parse(req.body);
      const result = await EmployeeService.create(req.user!.salonId, parsed);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to create employee' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const result = await EmployeeService.list(req.user!.salonId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list employees' });
    }
  }

  static async update(req: AuthRequest, res: Response) {
    try {
      const parsed = updateEmployeeSchema.parse(req.body);
      const result = await EmployeeService.update(req.user!.salonId, req.params.id, parsed);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to update employee' });
    }
  }
}
