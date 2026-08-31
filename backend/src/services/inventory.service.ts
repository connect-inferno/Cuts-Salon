import { getScopedPrisma } from '../utils/scopedPrisma';

interface InventoryItemInput {
  sku: string;
  name: string;
  category: string;
  price: number;
  costPrice: number;
  stockCount?: number;
  minAlertThreshold?: number;
}

export class InventoryService {
  static async create(salonId: string, input: InventoryItemInput) {
    const db = getScopedPrisma(salonId);
    const existing = await db.inventoryItem.findFirst({ where: { sku: input.sku } });
    if (existing) {
      throw new Error('An inventory item with this SKU already exists');
    }

    return db.inventoryItem.create({
      data: {
        salonId,
        sku: input.sku,
        name: input.name,
        category: input.category,
        price: input.price,
        costPrice: input.costPrice,
        stockCount: input.stockCount ?? 0,
        minAlertThreshold: input.minAlertThreshold ?? 5,
      },
    });
  }

  static async list(salonId: string) {
    const db = getScopedPrisma(salonId);
    return db.inventoryItem.findMany({ orderBy: { name: 'asc' } });
  }

  static async getById(salonId: string, id: string) {
    const db = getScopedPrisma(salonId);
    const item = await db.inventoryItem.findUnique({ where: { id } });
    if (!item) {
      throw new Error('Inventory item not found');
    }
    return item;
  }

  static async update(salonId: string, id: string, input: Partial<InventoryItemInput>) {
    const db = getScopedPrisma(salonId);
    const item = await db.inventoryItem.findUnique({ where: { id } });
    if (!item) {
      throw new Error('Inventory item not found');
    }

    return db.inventoryItem.update({
      where: { id },
      data: {
        sku: input.sku,
        name: input.name,
        category: input.category,
        price: input.price,
        costPrice: input.costPrice,
        stockCount: input.stockCount,
        minAlertThreshold: input.minAlertThreshold,
      },
    });
  }
}
