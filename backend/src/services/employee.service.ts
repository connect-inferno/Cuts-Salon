import prisma from '../utils/prisma';
import { getScopedPrisma } from '../utils/scopedPrisma';
import { hashPassword } from '../utils/hash';
import { Role } from '@prisma/client';

interface CreateEmployeeInput {
  name: string;
  phone: string;
  roleTitle: string;
  baseSalary: number;
  serviceCommissionPct: number;
  productCommissionPct: number;
  email: string;
  password: string;
}

interface UpdateEmployeeInput {
  name?: string;
  phone?: string;
  roleTitle?: string;
  baseSalary?: number;
  serviceCommissionPct?: number;
  productCommissionPct?: number;
  active?: boolean;
}

export class EmployeeService {
  static async create(salonId: string, input: CreateEmployeeInput) {
    const existingUser = await prisma.user.findUnique({ where: { email: input.email } });
    if (existingUser) {
      throw new Error('A user with this email already exists');
    }

    const db = getScopedPrisma(salonId);
    const existingPhone = await db.employeeProfile.findFirst({ where: { phone: input.phone } });
    if (existingPhone) {
      throw new Error('An employee with this phone number already exists');
    }

    const passwordHash = await hashPassword(input.password);

    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          salonId,
          email: input.email,
          passwordHash,
          role: Role.EMPLOYEE,
        },
      });

      const profile = await tx.employeeProfile.create({
        data: {
          salonId,
          userId: user.id,
          name: input.name,
          phone: input.phone,
          roleTitle: input.roleTitle,
          baseSalary: input.baseSalary,
          serviceCommissionPct: input.serviceCommissionPct,
          productCommissionPct: input.productCommissionPct,
        },
      });

      return { user, profile };
    });

    return {
      id: result.user.id,
      email: result.user.email,
      role: result.user.role,
      profile: {
        id: result.profile.id,
        name: result.profile.name,
        phone: result.profile.phone,
        roleTitle: result.profile.roleTitle,
        active: result.profile.active,
      },
    };
  }

  static async list(salonId: string) {
    const db = getScopedPrisma(salonId);
    const profiles = await db.employeeProfile.findMany({
      include: { user: { select: { email: true } } },
      orderBy: { createdAt: 'desc' },
    });

    return profiles.map((p) => ({
      id: p.id,
      userId: p.userId,
      email: p.user.email,
      name: p.name,
      phone: p.phone,
      roleTitle: p.roleTitle,
      active: p.active,
      baseSalary: p.baseSalary,
      serviceCommissionPct: p.serviceCommissionPct,
      productCommissionPct: p.productCommissionPct,
    }));
  }

  // Resolves the EmployeeProfile for the logged-in user - attendance,
  // salary, commissions, and discount requests all need "which employee
  // am I" from req.user.userId rather than a client-supplied employeeId.
  static async getProfileForUser(salonId: string, userId: string) {
    const db = getScopedPrisma(salonId);
    const profile = await db.employeeProfile.findUnique({ where: { userId } });
    if (!profile) {
      throw new Error('No employee profile found for this user');
    }
    return profile;
  }

  static async update(salonId: string, id: string, input: UpdateEmployeeInput) {
    const db = getScopedPrisma(salonId);
    const profile = await db.employeeProfile.findUnique({ where: { id } });
    if (!profile) {
      throw new Error('Employee not found');
    }

    return db.employeeProfile.update({
      where: { id },
      data: input,
    });
  }
}
