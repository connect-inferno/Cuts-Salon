import { getScopedPrisma } from '../utils/scopedPrisma';

interface CustomerInput {
  name: string;
  phone: string;
  email?: string;
  gender?: string;
  dob?: string;
  notes?: string;
  isVip?: boolean;
  branchId: string;
}

export class CustomerService {
  static async create(salonId: string, input: CustomerInput) {
    const db = getScopedPrisma(salonId);
    const existing = await db.customer.findFirst({ where: { phone: input.phone } });
    if (existing) {
      throw new Error('A customer with this phone number already exists');
    }

    const branch = await db.branch.findUnique({ where: { id: input.branchId } });
    if (!branch) {
      throw new Error('Branch not found');
    }

    return db.customer.create({
      data: {
        salonId,
        branchId: input.branchId,
        name: input.name,
        phone: input.phone,
        email: input.email,
        gender: input.gender,
        dob: input.dob ? new Date(input.dob) : undefined,
        notes: input.notes,
        isVip: input.isVip ?? false,
      },
    });
  }

  static async list(salonId: string, search?: string, branchId?: string) {
    const db = getScopedPrisma(salonId);
    return db.customer.findMany({
      where: {
        branchId,
        ...(search
          ? {
              OR: [
                { name: { contains: search, mode: 'insensitive' } },
                { phone: { contains: search } },
              ],
            }
          : {}),
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  static async getById(salonId: string, id: string) {
    const db = getScopedPrisma(salonId);
    const customer = await db.customer.findUnique({ where: { id } });
    if (!customer) {
      throw new Error('Customer not found');
    }
    return customer;
  }

  static async update(salonId: string, id: string, input: Partial<CustomerInput>) {
    const db = getScopedPrisma(salonId);
    const customer = await db.customer.findUnique({ where: { id } });
    if (!customer) {
      throw new Error('Customer not found');
    }

    if (input.branchId) {
      const branch = await db.branch.findUnique({ where: { id: input.branchId } });
      if (!branch) {
        throw new Error('Branch not found');
      }
    }

    return db.customer.update({
      where: { id },
      data: {
        name: input.name,
        phone: input.phone,
        email: input.email,
        gender: input.gender,
        dob: input.dob ? new Date(input.dob) : undefined,
        notes: input.notes,
        isVip: input.isVip,
        branchId: input.branchId,
      },
    });
  }
}
