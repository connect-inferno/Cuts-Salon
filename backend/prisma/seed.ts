import { PrismaClient, Role } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('[Seed] Starting database seed...');

  // Hash password
  const salt = await bcrypt.genSalt(10);
  const passwordHash = await bcrypt.hash('password123', salt);

  // 1. Create Owner User
  const owner = await prisma.user.upsert({
    where: { email: 'owner@salon.com' },
    update: {},
    create: {
      email: 'owner@salon.com',
      passwordHash,
      role: Role.OWNER,
    },
  });
  console.log(`[Seed] Owner user upserted: ${owner.email}`);

  // 2. Create Employee User
  const employeeUser = await prisma.user.upsert({
    where: { email: 'employee@salon.com' },
    update: {},
    create: {
      email: 'employee@salon.com',
      passwordHash,
      role: Role.EMPLOYEE,
    },
  });
  console.log(`[Seed] Employee user upserted: ${employeeUser.email}`);

  // 3. Create Employee Profile linked to Employee User
  const employeeProfile = await prisma.employeeProfile.upsert({
    where: { phone: '1234567890' },
    update: {},
    create: {
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

  // 4. Create default settings
  await prisma.settings.upsert({
    where: { id: 'global' },
    update: {},
    create: {
      id: 'global',
      salonName: 'Modern Glamour Salon',
      phone: '9876543210',
      address: '123 Fashion Street, City Centre',
      gstRate: 18.00,
      lateAttendancePenalty: 50.00,
    },
  });
  console.log('[Seed] Global settings upserted');

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
