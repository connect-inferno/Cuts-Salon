import { getScopedPrisma } from '../utils/scopedPrisma';

interface SettingsInput {
  salonName?: string;
  phone?: string;
  address?: string;
  gstRate?: number;
  lateAttendancePenalty?: number;
}

export class SettingsService {
  static async get(salonId: string) {
    const db = getScopedPrisma(salonId);
    const settings = await db.settings.findUnique({ where: { salonId } });
    if (!settings) {
      throw new Error('Settings not found for this salon');
    }
    return settings;
  }

  static async update(salonId: string, input: SettingsInput) {
    const db = getScopedPrisma(salonId);
    return db.settings.update({ where: { salonId }, data: input });
  }
}
