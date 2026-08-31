import { Response } from 'express';
import { z } from 'zod';
import { AttendanceService } from '../services/attendance.service';
import { AuthRequest } from '../middleware/auth.middleware';

const geoSchema = z.object({
  lat: z.number().optional(),
  lng: z.number().optional(),
});

const markSchema = z.object({
  employeeId: z.string().uuid(),
  date: z.string(),
  status: z.enum(['PRESENT', 'LATE', 'ABSENT']),
  notes: z.string().optional(),
});

export class AttendanceController {
  static async clockIn(req: AuthRequest, res: Response) {
    try {
      const { lat, lng } = geoSchema.parse(req.body);
      const result = await AttendanceService.clockIn(req.user!.salonId, req.user!.userId, lat, lng);
      return res.status(201).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to clock in' });
    }
  }

  static async clockOut(req: AuthRequest, res: Response) {
    try {
      const { lat, lng } = geoSchema.parse(req.body);
      const result = await AttendanceService.clockOut(req.user!.salonId, req.user!.userId, lat, lng);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to clock out' });
    }
  }

  static async list(req: AuthRequest, res: Response) {
    try {
      const employeeId = typeof req.query.employeeId === 'string' ? req.query.employeeId : undefined;
      const from = typeof req.query.from === 'string' ? req.query.from : undefined;
      const to = typeof req.query.to === 'string' ? req.query.to : undefined;
      const result = await AttendanceService.list(req.user!.salonId, req.user!, { employeeId, from, to });
      return res.status(200).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message || 'Failed to list attendance' });
    }
  }

  static async mark(req: AuthRequest, res: Response) {
    try {
      const parsed = markSchema.parse(req.body);
      const result = await AttendanceService.mark(req.user!.salonId, parsed.employeeId, parsed.date, parsed.status, parsed.notes);
      return res.status(200).json(result);
    } catch (error: any) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: error.errors[0].message });
      }
      return res.status(400).json({ error: error.message || 'Failed to mark attendance' });
    }
  }
}
