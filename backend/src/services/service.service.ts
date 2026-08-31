import { getScopedPrisma } from '../utils/scopedPrisma';

interface ServiceInput {
  name: string;
  price: number;
  categoryId: string;
}

export class ServiceCatalogService {
  static async create(salonId: string, input: ServiceInput) {
    const db = getScopedPrisma(salonId);

    const category = await db.serviceCategory.findUnique({ where: { id: input.categoryId } });
    if (!category) {
      throw new Error('Service category not found');
    }

    const existing = await db.service.findFirst({ where: { name: input.name } });
    if (existing) {
      throw new Error('A service with this name already exists');
    }

    return db.service.create({
      data: { salonId, name: input.name, price: input.price, categoryId: input.categoryId },
    });
  }

  static async list(salonId: string) {
    const db = getScopedPrisma(salonId);
    return db.service.findMany({ include: { category: true }, orderBy: { name: 'asc' } });
  }

  static async getById(salonId: string, id: string) {
    const db = getScopedPrisma(salonId);
    const service = await db.service.findUnique({ where: { id }, include: { category: true } });
    if (!service) {
      throw new Error('Service not found');
    }
    return service;
  }

  static async update(salonId: string, id: string, input: Partial<ServiceInput>) {
    const db = getScopedPrisma(salonId);
    const service = await db.service.findUnique({ where: { id } });
    if (!service) {
      throw new Error('Service not found');
    }

    if (input.categoryId) {
      const category = await db.serviceCategory.findUnique({ where: { id: input.categoryId } });
      if (!category) {
        throw new Error('Service category not found');
      }
    }

    return db.service.update({
      where: { id },
      data: { name: input.name, price: input.price, categoryId: input.categoryId },
    });
  }
}
