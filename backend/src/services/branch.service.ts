import { getScopedPrisma } from '../utils/scopedPrisma';

interface BranchInput {
  name: string;
  address?: string;
  phone?: string;
}

interface UpdateBranchInput {
  name?: string;
  address?: string;
  phone?: string;
  managerId?: string | null;
  active?: boolean;
}

function startOfMonth(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
}

export class BranchService {
  static async create(salonId: string, input: BranchInput) {
    const db = getScopedPrisma(salonId);
    const existing = await db.branch.findFirst({ where: { name: input.name } });
    if (existing) {
      throw new Error('A branch with this name already exists');
    }
    return db.branch.create({
      data: { salonId, name: input.name, address: input.address, phone: input.phone },
    });
  }

  static async list(salonId: string) {
    const db = getScopedPrisma(salonId);
    const branches = await db.branch.findMany({
      include: { manager: { select: { name: true } } },
      orderBy: { createdAt: 'asc' },
    });
    return Promise.all(branches.map((b) => this.withStats(salonId, b)));
  }

  static async getById(salonId: string, id: string) {
    const db = getScopedPrisma(salonId);
    const branch = await db.branch.findUnique({
      where: { id },
      include: { manager: { select: { name: true } } },
    });
    if (!branch) {
      throw new Error('Branch not found');
    }
    return this.withStats(salonId, branch);
  }

  static async update(salonId: string, id: string, input: UpdateBranchInput) {
    const db = getScopedPrisma(salonId);
    const branch = await db.branch.findUnique({ where: { id } });
    if (!branch) {
      throw new Error('Branch not found');
    }

    if (input.managerId) {
      const manager = await db.employeeProfile.findUnique({ where: { id: input.managerId } });
      if (!manager) {
        throw new Error('Manager must be an employee in this salon');
      }
      if (manager.branchId !== id) {
        throw new Error('Manager must be an employee assigned to this branch');
      }
    }

    return db.branch.update({
      where: { id },
      data: {
        name: input.name,
        address: input.address,
        phone: input.phone,
        managerId: input.managerId,
        active: input.active,
      },
    });
  }

  private static async withStats(salonId: string, branch: { id: string; manager: { name: string } | null } & Record<string, any>) {
    const db = getScopedPrisma(salonId);
    const [employeeCount, customerCount, revenueAgg] = await Promise.all([
      db.employeeProfile.count({ where: { branchId: branch.id } }),
      db.customer.count({ where: { branchId: branch.id } }),
      db.bill.aggregate({
        where: { branchId: branch.id, createdAt: { gte: startOfMonth() } },
        _sum: { finalAmount: true },
      }),
    ]);

    return {
      id: branch.id,
      name: branch.name,
      address: branch.address,
      phone: branch.phone,
      active: branch.active,
      managerId: branch.managerId,
      managerName: branch.manager?.name ?? null,
      employeeCount,
      customerCount,
      monthlyRevenue: Number(revenueAgg._sum.finalAmount ?? 0),
      createdAt: branch.createdAt,
    };
  }
}
