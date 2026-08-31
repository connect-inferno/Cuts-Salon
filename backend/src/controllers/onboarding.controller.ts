import { Request, Response } from 'express';
import { z } from 'zod';
import { OnboardingService } from '../services/onboarding.service';

const onboardSalonSchema = z.object({
  salonName: z.string().min(2, 'Salon name is required'),
  slug: z.string().min(2).optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  logoUrl: z.string().url('Logo must be a valid URL').optional().or(z.literal('')),
  ownerEmail: z.string().email('Invalid owner email address'),
  ownerPassword: z.string().min(8, 'Owner password must be at least 8 characters'),
});

export class OnboardingController {
  static async onboardSalon(req: Request, res: Response) {
    try {
      const parsedBody = onboardSalonSchema.parse(req.body);
      const result = await OnboardingService.onboardSalon({
        ...parsedBody,
        logoUrl: parsedBody.logoUrl || undefined,
      });
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to onboard salon' });
    }
  }

  static async listSalons(req: Request, res: Response) {
    try {
      const result = await OnboardingService.listSalons();
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list salons' });
    }
  }
}
