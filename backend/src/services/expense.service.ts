import { getScopedPrisma } from '../utils/scopedPrisma';
import { ExpenseCategory } from '@prisma/client';

interface ExpenseInput {
  title: string;
  amount: number;
  category: ExpenseCategory;
  date: string;
  receiptUrl?: string;
  notes?: string;
}

export class ExpenseService {
  static async create(salonId: string, createdBy: string, input: ExpenseInput) {
    const db = getScopedPrisma(salonId);
    return db.expense.create({
      data: {
        salonId,
        title: input.title,
        amount: input.amount,
        category: input.category,
        date: new Date(input.date),
        receiptUrl: input.receiptUrl,
        notes: input.notes,
        createdBy,
      },
    });
  }

  static async list(salonId: string, from?: string, to?: string) {
    const db = getScopedPrisma(salonId);
    return db.expense.findMany({
      where: {
        date: {
          gte: from ? new Date(from) : undefined,
          lte: to ? new Date(to) : undefined,
        },
      },
      orderBy: { date: 'desc' },
    });
  }

  static async update(salonId: string, id: string, input: Partial<ExpenseInput>) {
    const db = getScopedPrisma(salonId);
    const expense = await db.expense.findUnique({ where: { id } });
    if (!expense) {
      throw new Error('Expense not found');
    }

    return db.expense.update({
      where: { id },
      data: {
        title: input.title,
        amount: input.amount,
        category: input.category,
        date: input.date ? new Date(input.date) : undefined,
        receiptUrl: input.receiptUrl,
        notes: input.notes,
      },
    });
  }
}
