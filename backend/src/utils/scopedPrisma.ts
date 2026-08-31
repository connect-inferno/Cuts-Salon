import prisma from './prisma';

// Models that carry a salonId column and must never be queried/written
// without being scoped to the caller's salon.
const TENANT_SCOPED_MODELS = new Set([
  'EmployeeProfile',
  'Customer',
  'ServiceCategory',
  'Service',
  'InventoryItem',
  'StockTransaction',
  'Bill',
  'BillItem',
  'AttendanceRecord',
  'SalaryRecord',
  'CommissionRecord',
  'SalesTarget',
  'Expense',
  'DiscountRequest',
  'Settings',
]);

const READ_OR_DELETE_OPS = new Set([
  'findFirst',
  'findFirstOrThrow',
  'findUnique',
  'findUniqueOrThrow',
  'findMany',
  'count',
  'aggregate',
  'groupBy',
  'update',
  'updateMany',
  'delete',
  'deleteMany',
]);

// Returns a Prisma client that automatically scopes every query on a
// tenant-owned model to the given salonId - injects salonId into `where`
// on reads/updates/deletes, and into `data` on creates. Controllers should
// always use this (never the raw `prisma` import) once salonId is known
// from the authenticated request.
export function getScopedPrisma(salonId: string) {
  return prisma.$extends({
    name: 'tenant-scope',
    query: {
      $allModels: {
        async $allOperations({ model, operation, args, query }) {
          if (!model || !TENANT_SCOPED_MODELS.has(model)) {
            return query(args);
          }

          const scopedArgs: any = args;

          if (READ_OR_DELETE_OPS.has(operation)) {
            scopedArgs.where = { ...(scopedArgs.where ?? {}), salonId };
          } else if (operation === 'create') {
            scopedArgs.data = { ...(scopedArgs.data ?? {}), salonId };
          } else if (operation === 'createMany' && Array.isArray(scopedArgs.data)) {
            scopedArgs.data = scopedArgs.data.map((row: any) => ({ ...row, salonId }));
          } else if (operation === 'upsert') {
            scopedArgs.where = { ...(scopedArgs.where ?? {}), salonId };
            scopedArgs.create = { ...(scopedArgs.create ?? {}), salonId };
          }

          return query(scopedArgs);
        },
      },
    },
  });
}
