import { PrismaClient, Role } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('[Seed] Starting database seed...');

  const salon = await prisma.salon.upsert({
    where: { slug: 'modern-glamour' },
    update: {},
    create: {
      name: 'Modern Glamour Salon',
      slug: 'modern-glamour',
      phone: '9876543210',
      address: '123 Fashion Street, City Centre',
    },
  });
  console.log(`[Seed] Salon upserted: ${salon.name}`);

  const salt = await bcrypt.genSalt(10);
  const passwordHash = await bcrypt.hash('password123', salt);

  const owner = await prisma.user.upsert({
    where: { email: 'owner@salon.com' },
    update: {},
    create: {
      salonId: salon.id,
      email: 'owner@salon.com',
      passwordHash,
      role: Role.OWNER,
    },
  });
  console.log(`[Seed] Owner user upserted: ${owner.email}`);

  const employeeUser = await prisma.user.upsert({
    where: { email: 'employee@salon.com' },
    update: {},
    create: {
      salonId: salon.id,
      email: 'employee@salon.com',
      passwordHash,
      role: Role.EMPLOYEE,
    },
  });
  console.log(`[Seed] Employee user upserted: ${employeeUser.email}`);

  const employeeProfile = await prisma.employeeProfile.upsert({
    where: { salonId_phone: { salonId: salon.id, phone: '1234567890' } },
    update: {},
    create: {
      salonId: salon.id,
      userId: employeeUser.id,
      name: 'Sarah Stylist',
      phone: '1234567890',
      roleTitle: 'Senior Hair Stylist',
      active: true,
      baseSalary: 3000.00,
      serviceCommissionPct: 15.00, // 15%
      productCommissionPct: 5.00,   // 5%
    },
  });
  console.log(`[Seed] Employee profile upserted: ${employeeProfile.name}`);

  await prisma.settings.upsert({
    where: { salonId: salon.id },
    update: {},
    create: {
      salonId: salon.id,
      salonName: salon.name,
      phone: salon.phone,
      address: salon.address,
      gstRate: 18.00,
      lateAttendancePenalty: 50.00,
    },
  });
  console.log('[Seed] Salon settings upserted');

  console.log('[Seed] Database seed completed successfully.');
}

main()
  .catch((e) => {
    console.error('[Seed] Error running seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
