import { Prisma, BillItemType, PaymentMethod, TargetType, TargetStatus } from '@prisma/client';
import { getScopedPrisma } from '../utils/scopedPrisma';

interface BillItemInput {
  type: BillItemType;
  serviceId?: string;
  inventoryItemId?: string;
  employeeId: string;
  quantity?: number;
  unitPrice?: number;
  priceOverrideReason?: string;
  discountAmount?: number;
}

interface CreateBillInput {
  customerId: string;
  branchId: string;
  paymentMethod: PaymentMethod;
  discountAmount?: number;
  items: BillItemInput[];
}

const round2 = (n: number) => Math.round(n * 100) / 100;

interface ResolvedBillItem {
  type: BillItemType;
  serviceId?: string;
  inventoryItemId?: string;
  employeeId: string;
  quantity: number;
  unitPrice: number;
  priceOverrideReason?: string;
  discountAmount: number;
  calculatedCommission: number;
}

export class BillService {
  static async create(salonId: string, createdBy: string, input: CreateBillInput) {
    if (!input.items || input.items.length === 0) {
      throw new Error('A bill must have at least one item');
    }

    const db = getScopedPrisma(salonId);

    const customer = await db.customer.findUnique({ where: { id: input.customerId } });
    if (!customer) {
      throw new Error('Customer not found');
    }

    const branch = await db.branch.findUnique({ where: { id: input.branchId } });
    if (!branch) {
      throw new Error('Branch not found');
    }

    const settings = await db.settings.findUnique({ where: { salonId } });
    const gstRate = Number(settings?.gstRate ?? 18);

    // Resolve catalog price, employee commission rate, and stock availability
    // for every item up front so the transaction below never has to fail
    // partway through for a business-logic reason (only for race conditions).
    const resolvedItems: ResolvedBillItem[] = [];
    let subTotal = 0;
    let itemDiscountTotal = 0;

    for (const item of input.items) {
      if (item.type === BillItemType.SERVICE && !item.serviceId) {
        throw new Error('serviceId is required for SERVICE items');
      }
      if (item.type === BillItemType.PRODUCT && !item.inventoryItemId) {
        throw new Error('inventoryItemId is required for PRODUCT items');
      }

      const employee = await db.employeeProfile.findUnique({ where: { id: item.employeeId } });
      if (!employee || !employee.active) {
        throw new Error('Employee not found or inactive');
      }

      let catalogPrice: number;
      let productName: string | undefined;

      if (item.type === BillItemType.SERVICE) {
        const service = await db.service.findUnique({ where: { id: item.serviceId! } });
        if (!service) throw new Error('Service not found');
        catalogPrice = Number(service.price);
      } else {
        const inventoryItem = await db.inventoryItem.findUnique({ where: { id: item.inventoryItemId! } });
        if (!inventoryItem) throw new Error('Inventory item not found');
        const quantity = item.quantity ?? 1;
        if (inventoryItem.stockCount < quantity) {
          throw new Error(`Insufficient stock for ${inventoryItem.name} (have ${inventoryItem.stockCount}, need ${quantity})`);
        }
        catalogPrice = Number(inventoryItem.price);
        productName = inventoryItem.name;
      }

      const quantity = item.quantity ?? 1;
      const unitPrice = item.unitPrice ?? catalogPrice;
      if (item.unitPrice !== undefined && item.unitPrice !== catalogPrice && !item.priceOverrideReason) {
        throw new Error(`priceOverrideReason is required to override the catalog price${productName ? ` for ${productName}` : ''}`);
      }

      const itemDiscount = item.discountAmount ?? 0;
      const baseAmount = round2(unitPrice * quantity);
      const netAmount = round2(baseAmount - itemDiscount);
      const commissionPct = Number(
        item.type === BillItemType.SERVICE ? employee.serviceCommissionPct : employee.productCommissionPct
      );
      const calculatedCommission = round2(netAmount * (commissionPct / 100));

      subTotal += baseAmount;
      itemDiscountTotal += itemDiscount;

      resolvedItems.push({
        type: item.type,
        serviceId: item.serviceId,
        inventoryItemId: item.inventoryItemId,
        employeeId: item.employeeId,
        quantity,
        unitPrice,
        priceOverrideReason: item.priceOverrideReason,
        discountAmount: itemDiscount,
        calculatedCommission,
      });
    }

    subTotal = round2(subTotal);
    const billDiscount = round2(itemDiscountTotal + (input.discountAmount ?? 0));
    const taxableAmount = round2(subTotal - billDiscount);
    const taxAmount = round2(taxableAmount * (gstRate / 100));
    const finalAmount = round2(taxableAmount + taxAmount);

    const billCount = await db.bill.count();
    let attempt = 0;
    let lastError: unknown;

    while (attempt < 5) {
      const invoiceNumber = `INV-${String(billCount + 1 + attempt).padStart(6, '0')}`;
      try {
        return await db.$transaction(async (tx) => {
          const bill = await tx.bill.create({
            data: {
              salonId,
              branchId: input.branchId,
              invoiceNumber,
              customerId: input.customerId,
              subTotal,
              discountAmount: billDiscount,
              taxAmount,
              finalAmount,
              paymentMethod: input.paymentMethod,
              createdBy,
            },
          });

          for (const item of resolvedItems) {
            const billItem = await tx.billItem.create({
              data: {
                salonId,
                billId: bill.id,
                type: item.type,
                serviceId: item.serviceId,
                inventoryItemId: item.inventoryItemId,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                priceOverrideReason: item.priceOverrideReason,
                discountAmount: item.discountAmount,
                employeeId: item.employeeId,
                calculatedCommission: item.calculatedCommission,
              },
            });

            await tx.commissionRecord.create({
              data: {
                salonId,
                employeeId: item.employeeId,
                billItemId: billItem.id,
                amount: item.calculatedCommission,
              },
            });

            const targetType = item.type === BillItemType.SERVICE ? TargetType.SERVICE_VOLUME : TargetType.PRODUCT_SALES_COUNT;
            const progressIncrement = item.type === BillItemType.SERVICE
              ? round2(item.unitPrice * item.quantity - item.discountAmount)
              : item.quantity;
            const now = new Date();
            // endDate is often just a date (stored at midnight) - compare
            // against the start of today rather than the exact instant so
            // a target ending "today" still counts as active all day.
            const todayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
            const activeTargets = await tx.salesTarget.findMany({
              where: {
                employeeId: item.employeeId,
                type: targetType,
                status: TargetStatus.ACTIVE,
                startDate: { lte: now },
                endDate: { gte: todayStart },
              },
            });
            for (const target of activeTargets) {
              const newProgress = round2(Number(target.progressValue) + progressIncrement);
              await tx.salesTarget.update({
                where: { id: target.id },
                data: {
                  progressValue: newProgress,
                  status: newProgress >= Number(target.targetValue) ? TargetStatus.ACHIEVED : undefined,
                },
              });
            }

            if (item.type === BillItemType.PRODUCT && item.inventoryItemId) {
              await tx.inventoryItem.update({
                where: { id: item.inventoryItemId },
                data: { stockCount: { decrement: item.quantity } },
              });

              await tx.stockTransaction.create({
                data: {
                  salonId,
                  inventoryItemId: item.inventoryItemId,
                  type: 'SALE',
                  quantity: item.quantity,
                  reason: `Sale on invoice ${invoiceNumber}`,
                  employeeId: item.employeeId,
                },
              });
            }
          }

          return tx.bill.findUnique({
            where: { id: bill.id },
            include: { items: true, customer: true },
          });
        });
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
          lastError = error;
          attempt += 1;
          continue;
        }
        throw error;
      }
    }

    throw lastError instanceof Error ? lastError : new Error('Failed to generate a unique invoice number');
  }

  static async list(salonId: string, from?: string, to?: string, branchId?: string) {
    const db = getScopedPrisma(salonId);
    return db.bill.findMany({
      where: {
        branchId,
        createdAt: {
          gte: from ? new Date(from) : undefined,
          lte: to ? new Date(to) : undefined,
        },
      },
      include: { customer: true, items: { include: { service: true, inventoryItem: true, employee: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  static async getById(salonId: string, id: string) {
    const db = getScopedPrisma(salonId);
    const bill = await db.bill.findUnique({
      where: { id },
      include: { customer: true, items: { include: { service: true, inventoryItem: true, employee: true } } },
    });
    if (!bill) {
      throw new Error('Bill not found');
    }
    return bill;
  }
}
