import { getScopedPrisma } from '../utils/scopedPrisma';
import { BillStatus, DiscountReqStatus } from '@prisma/client';

const round2 = (n: number) => Math.round(n * 100) / 100;

export class DashboardService {
  static async summary(salonId: string) {
    const db = getScopedPrisma(salonId);
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - 6);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const [todayBills, weekBills, monthBills, todayAttendanceCount, pendingDiscountRequests, inventoryItems] = await Promise.all([
      db.bill.findMany({ where: { status: BillStatus.COMPLETED, createdAt: { gte: todayStart } } }),
      db.bill.findMany({ where: { status: BillStatus.COMPLETED, createdAt: { gte: weekStart } } }),
      db.bill.findMany({ where: { status: BillStatus.COMPLETED, createdAt: { gte: monthStart } } }),
      db.attendanceRecord.count({ where: { date: todayStart, status: { in: ['PRESENT', 'LATE'] } } }),
      db.discountRequest.count({ where: { status: DiscountReqStatus.PENDING } }),
      db.inventoryItem.findMany(),
    ]);

    const sumFinal = (bills: { finalAmount: any }[]) => round2(bills.reduce((s, b) => s + Number(b.finalAmount), 0));
    const sumByMethod = (method: string) =>
      round2(todayBills.filter((b: any) => b.paymentMethod === method).reduce((s, b) => s + Number(b.finalAmount), 0));

    return {
      todaySales: sumFinal(todayBills),
      weekSales: sumFinal(weekBills),
      monthSales: sumFinal(monthBills),
      todayPaymentBreakdown: {
        CASH: sumByMethod('CASH'),
        CARD: sumByMethod('CARD'),
        UPI: sumByMethod('UPI'),
      },
      todayCustomersCount: new Set(todayBills.map((b: any) => b.customerId)).size,
      todayBillCount: todayBills.length,
      todayAttendanceCount,
      pendingDiscountRequests,
      lowStockItemCount: inventoryItems.filter((i) => i.stockCount <= i.minAlertThreshold).length,
    };
  }
}
