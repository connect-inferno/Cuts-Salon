import { Response } from 'express';
import { z } from 'zod';
import { SettingsService } from '../services/settings.service';
import { AuthRequest } from '../middleware/auth.middleware';

const updateSettingsSchema = z.object({
  salonName: z.string().min(1).optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  gstRate: z.number().min(0).max(100).optional(),
  lateAttendancePenalty: z.number().nonnegative().optional(),
});

export class SettingsController {
  static async get(req: AuthRequest, res: Response) {
    try {
      const result = await SettingsService.get(req.user!.salonId);
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(404).json({ error: error.message || 'Settings not found' });
    }
  }

  static async update(req: AuthRequest, res: Response) {
    try {
      const parsed = updateSettingsSchema.parse(req.body);
      const result = await SettingsService.update(req.user!.salonId, parsed);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to update settings' });
    }
  }
}
