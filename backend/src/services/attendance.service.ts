import { getScopedPrisma } from '../utils/scopedPrisma';
import { EmployeeService } from './employee.service';
import { AttendanceStatus } from '@prisma/client';

// Built from UTC components so the stored @db.Date value doesn't shift by
// a day depending on the server process's local timezone.
const startOfDay = (d: Date) => new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));

export class AttendanceService {
  static async clockIn(salonId: string, userId: string, lat?: number, lng?: number) {
    const profile = await EmployeeService.getProfileForUser(salonId, userId);
    const db = getScopedPrisma(salonId);
    const today = startOfDay(new Date());

    const existing = await db.attendanceRecord.findUnique({
      where: { employeeId_date: { employeeId: profile.id, date: today } },
    });
    if (existing) {
      throw new Error('Already clocked in today');
    }

    return db.attendanceRecord.create({
      data: {
        salonId,
        employeeId: profile.id,
        date: today,
        clockIn: new Date(),
        status: AttendanceStatus.PRESENT,
        latIn: lat,
        lngIn: lng,
      },
    });
  }

  static async clockOut(salonId: string, userId: string, lat?: number, lng?: number) {
    const profile = await EmployeeService.getProfileForUser(salonId, userId);
    const db = getScopedPrisma(salonId);
    const today = startOfDay(new Date());

    const existing = await db.attendanceRecord.findUnique({
      where: { employeeId_date: { employeeId: profile.id, date: today } },
    });
    if (!existing) {
      throw new Error('You have not clocked in today');
    }
    if (existing.clockOut) {
      throw new Error('Already clocked out today');
    }

    return db.attendanceRecord.update({
      where: { id: existing.id },
      data: { clockOut: new Date(), latOut: lat, lngOut: lng },
    });
  }

  static async list(
    salonId: string,
    requester: { userId: string; role: string },
    filters: { employeeId?: string; from?: string; to?: string }
  ) {
    const db = getScopedPrisma(salonId);

    let employeeId = filters.employeeId;
    if (requester.role !== 'OWNER') {
      const profile = await EmployeeService.getProfileForUser(salonId, requester.userId);
      employeeId = profile.id;
    }

    return db.attendanceRecord.findMany({
      where: {
        employeeId,
        date: {
          gte: filters.from ? startOfDay(new Date(filters.from)) : undefined,
          lte: filters.to ? startOfDay(new Date(filters.to)) : undefined,
        },
      },
      include: { employee: { select: { name: true } } },
      orderBy: { date: 'desc' },
    });
  }

  // Owner-driven correction (e.g. marking someone ABSENT after the fact) -
  // no real punch times exist for this, so clockIn is set to the start of
  // the given day as a sentinel rather than a real event time.
  static async mark(salonId: string, employeeId: string, date: string, status: AttendanceStatus, notes?: string) {
    const db = getScopedPrisma(salonId);
    const day = startOfDay(new Date(date));

    const employee = await db.employeeProfile.findUnique({ where: { id: employeeId } });
    if (!employee) {
      throw new Error('Employee not found');
    }

    return db.attendanceRecord.upsert({
      where: { employeeId_date: { employeeId, date: day } },
      update: { status, notes },
      create: { salonId, employeeId, date: day, clockIn: day, status, notes },
    });
  }
}
