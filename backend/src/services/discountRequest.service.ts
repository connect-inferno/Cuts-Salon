import crypto from 'crypto';
import { getScopedPrisma } from '../utils/scopedPrisma';
import { DiscountReqStatus } from '@prisma/client';

interface CreateDiscountRequestInput {
  billId?: string;
  requestedDiscount: number;
  overridePrice?: number;
  reason: string;
}

export class DiscountRequestService {
  static async create(salonId: string, requestedBy: string, input: CreateDiscountRequestInput) {
    const db = getScopedPrisma(salonId);
    return db.discountRequest.create({
      data: {
        salonId,
        requestedBy,
        billId: input.billId,
        requestedDiscount: input.requestedDiscount,
        overridePrice: input.overridePrice,
        reason: input.reason,
      },
    });
  }

  static async list(salonId: string, requester: { userId: string; role: string }, status?: DiscountReqStatus) {
    const db = getScopedPrisma(salonId);
    return db.discountRequest.findMany({
      where: {
        requestedBy: requester.role === 'OWNER' ? undefined : requester.userId,
        status,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  static async approve(salonId: string, id: string, resolvedBy: string) {
    const db = getScopedPrisma(salonId);
    const request = await db.discountRequest.findUnique({ where: { id } });
    if (!request) {
      throw new Error('Discount request not found');
    }
    if (request.status !== DiscountReqStatus.PENDING) {
      throw new Error('Only pending requests can be approved');
    }

    const authorizedCode = crypto.randomBytes(4).toString('hex').toUpperCase();
    return db.discountRequest.update({
      where: { id },
      data: { status: DiscountReqStatus.APPROVED, resolvedBy, authorizedCode },
    });
  }

  static async reject(salonId: string, id: string, resolvedBy: string) {
    const db = getScopedPrisma(salonId);
    const request = await db.discountRequest.findUnique({ where: { id } });
    if (!request) {
      throw new Error('Discount request not found');
    }
    if (request.status !== DiscountReqStatus.PENDING) {
      throw new Error('Only pending requests can be rejected');
    }

    return db.discountRequest.update({
      where: { id },
      data: { status: DiscountReqStatus.REJECTED, resolvedBy },
    });
  }
}
