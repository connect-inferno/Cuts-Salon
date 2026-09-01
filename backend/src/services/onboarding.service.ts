import prisma from '../utils/prisma';
import { hashPassword } from '../utils/hash';
import { slugify } from '../utils/slugify';
import { Role } from '@prisma/client';

interface OnboardSalonInput {
  salonName: string;
  slug?: string;
  phone?: string;
  address?: string;
  logoUrl?: string;
  ownerEmail: string;
  ownerPassword: string;
}

export class OnboardingService {
  static async onboardSalon(input: OnboardSalonInput) {
    const baseSlug = slugify(input.slug || input.salonName);
    if (!baseSlug) {
      throw new Error('Salon name must contain at least one letter or number');
    }

    const existingUser = await prisma.user.findUnique({ where: { email: input.ownerEmail } });
    if (existingUser) {
      throw new Error('A user with this email already exists');
    }

    const slug = await this.findAvailableSlug(baseSlug);
    const passwordHash = await hashPassword(input.ownerPassword);

    const result = await prisma.$transaction(async (tx) => {
      const salon = await tx.salon.create({
        data: {
          name: input.salonName,
          slug,
          phone: input.phone,
          address: input.address,
          logoUrl: input.logoUrl,
        },
      });

      const owner = await tx.user.create({
        data: {
          salonId: salon.id,
          email: input.ownerEmail,
          passwordHash,
          role: Role.OWNER,
        },
      });

      await tx.settings.create({
        data: {
          salonId: salon.id,
          salonName: salon.name,
          phone: salon.phone,
          address: salon.address,
        },
      });

      // Every salon needs at least one branch before it can have any
      // employees, customers, or bills (all require a branchId).
      const branch = await tx.branch.create({
        data: {
          salonId: salon.id,
          name: 'Main Branch',
          address: input.address,
          phone: input.phone,
        },
      });

      return { salon, owner, branch };
    });

    return {
      salon: {
        id: result.salon.id,
        name: result.salon.name,
        slug: result.salon.slug,
        logoUrl: result.salon.logoUrl,
      },
      owner: {
        id: result.owner.id,
        email: result.owner.email,
        role: result.owner.role,
      },
      branch: {
        id: result.branch.id,
        name: result.branch.name,
      },
    };
  }

  static async listSalons() {
    const salons = await prisma.salon.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        users: {
          where: { role: Role.OWNER },
          select: { email: true },
          take: 1,
        },
      },
    });

    return salons.map((salon) => ({
      id: salon.id,
      name: salon.name,
      slug: salon.slug,
      phone: salon.phone,
      address: salon.address,
      logoUrl: salon.logoUrl,
      active: salon.active,
      createdAt: salon.createdAt,
      ownerEmail: salon.users[0]?.email ?? null,
    }));
  }

  private static async findAvailableSlug(baseSlug: string): Promise<string> {
    let candidate = baseSlug;
    let suffix = 1;
    while (await prisma.salon.findUnique({ where: { slug: candidate } })) {
      suffix += 1;
      candidate = `${baseSlug}-${suffix}`;
    }
    return candidate;
  }
}
