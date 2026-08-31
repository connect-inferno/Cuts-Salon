import { getScopedPrisma } from '../utils/scopedPrisma';
import { EmployeeService } from './employee.service';
import { CommissionStatus, SalaryStatus, AttendanceStatus } from '@prisma/client';

const round2 = (n: number) => Math.round(n * 100) / 100;

export class SalaryService {
  // Computes baseSalary + commissionEarned - deductions for the given
  // month/year, one salary record per active employee (or a single
  // employee if employeeId is given). Pending commissions in the period
  // are marked PAID as part of this - the schema has no separate "locked
  // into a draft" state, so this is the only way to snapshot which
  // commissions a salary figure was computed from and avoid double-
  // counting them into a later month's run.
  static async generate(salonId: string, month: number, year: number, employeeId?: string) {
    const db = getScopedPrisma(salonId);
    const periodStart = new Date(year, month - 1, 1);
    const periodEnd = new Date(year, month, 0, 23, 59, 59, 999);

    const employees = await db.employeeProfile.findMany({
      where: { active: true, id: employeeId },
    });
    if (employees.length === 0) {
      throw new Error('No matching active employees found');
    }

    const settings = await db.settings.findUnique({ where: { salonId } });
    const lateAttendancePenalty = Number(settings?.lateAttendancePenalty ?? 0);

    const results = [];
    for (const employee of employees) {
      const existing = await db.salaryRecord.findUnique({
        where: { employeeId_month_year: { employeeId: employee.id, month, year } },
      });
      if (existing && existing.status === SalaryStatus.PAID) {
        continue;
      }

      const pendingCommissions = await db.commissionRecord.findMany({
        where: {
          employeeId: employee.id,
          status: CommissionStatus.PENDING,
          calculatedAt: { gte: periodStart, lte: periodEnd },
        },
      });
      const commissionEarned = round2(pendingCommissions.reduce((sum, c) => sum + Number(c.amount), 0));

      const lateCount = await db.attendanceRecord.count({
        where: { employeeId: employee.id, status: AttendanceStatus.LATE, date: { gte: periodStart, lte: periodEnd } },
      });
      const deductions = round2(lateCount * lateAttendancePenalty);

      const baseSalary = Number(employee.baseSalary);
      const totalPaid = round2(baseSalary + commissionEarned - deductions);

      const record = await db.$transaction(async (tx) => {
        const salaryRecord = await tx.salaryRecord.upsert({
          where: { employeeId_month_year: { employeeId: employee.id, month, year } },
          update: { baseSalary, commissionEarned, deductions, totalPaid, status: SalaryStatus.DRAFT },
          create: { salonId, employeeId: employee.id, month, year, baseSalary, commissionEarned, deductions, totalPaid, status: SalaryStatus.DRAFT },
        });

        if (pendingCommissions.length > 0) {
          await tx.commissionRecord.updateMany({
            where: { id: { in: pendingCommissions.map((c) => c.id) } },
            data: { status: CommissionStatus.PAID, paidAt: new Date() },
          });
        }

        return salaryRecord;
      });

      results.push(record);
    }

    return results;
  }

  static async list(salonId: string, requester: { userId: string; role: string }, filters: { month?: number; year?: number; employeeId?: string }) {
    const db = getScopedPrisma(salonId);

    let employeeId = filters.employeeId;
    if (requester.role !== 'OWNER') {
      const profile = await EmployeeService.getProfileForUser(salonId, requester.userId);
      employeeId = profile.id;
    }

    return db.salaryRecord.findMany({
      where: { employeeId, month: filters.month, year: filters.year },
      include: { employee: { select: { name: true } } },
      orderBy: [{ year: 'desc' }, { month: 'desc' }],
    });
  }

  static async markPaid(salonId: string, id: string) {
    const db = getScopedPrisma(salonId);
    const record = await db.salaryRecord.findUnique({ where: { id } });
    if (!record) {
      throw new Error('Salary record not found');
    }
    return db.salaryRecord.update({
      where: { id },
      data: { status: SalaryStatus.PAID, paidAt: new Date() },
    });
  }
}
