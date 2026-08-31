import { getScopedPrisma } from '../utils/scopedPrisma';
import { EmployeeService } from './employee.service';
import { TargetType } from '@prisma/client';

interface CreateTargetInput {
  employeeId: string;
  type: TargetType;
  targetValue: number;
  startDate: string;
  endDate: string;
}

export class SalesTargetService {
  static async create(salonId: string, input: CreateTargetInput) {
    const db = getScopedPrisma(salonId);
    const employee = await db.employeeProfile.findUnique({ where: { id: input.employeeId } });
    if (!employee) {
      throw new Error('Employee not found');
    }

    return db.salesTarget.create({
      data: {
        salonId,
        employeeId: input.employeeId,
        type: input.type,
        targetValue: input.targetValue,
        startDate: new Date(input.startDate),
        endDate: new Date(input.endDate),
      },
    });
  }

  static async list(salonId: string, requester: { userId: string; role: string }, employeeIdFilter?: string) {
    const db = getScopedPrisma(salonId);

    let employeeId = employeeIdFilter;
    if (requester.role !== 'OWNER') {
      const profile = await EmployeeService.getProfileForUser(salonId, requester.userId);
      employeeId = profile.id;
    }

    return db.salesTarget.findMany({
      where: { employeeId },
      include: { employee: { select: { name: true } } },
      orderBy: { startDate: 'desc' },
    });
  }

  static async update(salonId: string, id: string, input: Partial<Pick<CreateTargetInput, 'targetValue' | 'startDate' | 'endDate'>>) {
    const db = getScopedPrisma(salonId);
    const target = await db.salesTarget.findUnique({ where: { id } });
    if (!target) {
      throw new Error('Sales target not found');
    }

    return db.salesTarget.update({
      where: { id },
      data: {
        targetValue: input.targetValue,
        startDate: input.startDate ? new Date(input.startDate) : undefined,
        endDate: input.endDate ? new Date(input.endDate) : undefined,
      },
    });
  }
}
