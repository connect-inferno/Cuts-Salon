import { getScopedPrisma } from '../utils/scopedPrisma';

export class ServiceCategoryService {
  static async create(salonId: string, name: string) {
    const db = getScopedPrisma(salonId);
    const existing = await db.serviceCategory.findFirst({ where: { name } });
    if (existing) {
      throw new Error('A category with this name already exists');
    }
    return db.serviceCategory.create({ data: { salonId, name } });
  }

  static async list(salonId: string) {
    const db = getScopedPrisma(salonId);
    return db.serviceCategory.findMany({ orderBy: { name: 'asc' } });
  }

  static async update(salonId: string, id: string, name: string) {
    const db = getScopedPrisma(salonId);
    const category = await db.serviceCategory.findUnique({ where: { id } });
    if (!category) {
      throw new Error('Service category not found');
    }
    return db.serviceCategory.update({ where: { id }, data: { name } });
  }
}
