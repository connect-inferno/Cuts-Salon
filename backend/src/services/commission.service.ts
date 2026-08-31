import { getScopedPrisma } from '../utils/scopedPrisma';
import { EmployeeService } from './employee.service';
import { CommissionStatus } from '@prisma/client';

export class CommissionService {
  static async list(salonId: string, requester: { userId: string; role: string }, employeeIdFilter?: string, status?: CommissionStatus) {
    const db = getScopedPrisma(salonId);

    let employeeId = employeeIdFilter;
    if (requester.role !== 'OWNER') {
      const profile = await EmployeeService.getProfileForUser(salonId, requester.userId);
      employeeId = profile.id;
    }

    return db.commissionRecord.findMany({
      where: { employeeId, status },
      include: { employee: { select: { name: true } }, billItem: true },
      orderBy: { calculatedAt: 'desc' },
    });
  }

  static async markPaid(salonId: string, id: string) {
    const db = getScopedPrisma(salonId);
    const record = await db.commissionRecord.findUnique({ where: { id } });
    if (!record) {
      throw new Error('Commission record not found');
    }
    return db.commissionRecord.update({
      where: { id },
      data: { status: CommissionStatus.PAID, paidAt: new Date() },
    });
  }
}
