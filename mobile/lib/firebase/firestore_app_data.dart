import '../data/app_data.dart';
import '../data/models.dart';
import '../features/auth/auth_state.dart';
import 'firestore_models.dart';
import 'salon_firestore.dart';

double _round2(num n) => (n * 100).round() / 100;

// Pure FS* (Firestore-native) -> app-facing model mappers. Kept separate
// from firestore_models.dart because these depend on data/models.dart,
// which the FS models themselves deliberately don't - firestore_models.dart
// mirrors Firestore documents 1:1, these mirror what the REST backend's
// JSON responses look like, including fields computed server-side there
// (branch stats, pay redaction) that have no Firestore-document equivalent.

Branch branchFromFS(FSBranch b, {required int employeeCount, required int customerCount, required double monthlyRevenue}) => Branch(
      id: b.id,
      name: b.name,
      address: b.address,
      phone: b.phone,
      active: b.active,
      managerId: b.managerId,
      managerName: b.managerName,
      employeeCount: employeeCount,
      customerCount: customerCount,
      monthlyRevenue: monthlyRevenue,
    );

// canSeePay mirrors employee.service.ts's exact rule (owner, or your own
// profile) - Firestore rules grant/deny a whole document, not fields, so
// this redaction has to happen here instead. Coercing to 0 matches
// EmployeeProfile.fromJson's own handling of the REST backend sending null
// for a hidden pay field.
EmployeeProfile employeeFromFS(FSEmployee e, {required bool canSeePay}) => EmployeeProfile(
      id: e.id,
      userId: e.userId,
      email: e.email,
      name: e.name,
      phone: e.phone,
      roleTitle: e.roleTitle,
      active: e.active,
      baseSalary: canSeePay ? e.baseSalary : 0,
      serviceCommissionPct: canSeePay ? e.serviceCommissionPct : 0,
      productCommissionPct: canSeePay ? e.productCommissionPct : 0,
      branchId: e.branchId,
      branchName: e.branchName,
    );

Customer customerFromFS(FSCustomer c) => Customer(
      id: c.id,
      name: c.name,
      phone: c.phone,
      email: c.email,
      gender: c.gender,
      notes: c.notes,
      isVip: c.isVip,
      branchId: c.branchId,
      createdAt: c.createdAt,
      visitCount: c.visitCount,
      totalSpent: c.totalSpent,
      outstandingBalance: c.outstandingBalance,
      lastVisitAt: c.lastVisitAt,
      archived: c.archived,
    );

ServiceCategory categoryFromFS(FSServiceCategory c) => ServiceCategory(id: c.id, name: c.name);

SalonService serviceFromFS(FSService s) => SalonService(
      id: s.id,
      name: s.name,
      price: s.price,
      categoryId: s.categoryId,
      categoryName: s.categoryName,
    );

InventoryItem inventoryFromFS(FSInventoryItem i) => InventoryItem(
      id: i.id,
      sku: i.sku,
      name: i.name,
      category: i.category,
      price: i.price,
      costPrice: i.costPrice,
      stockCount: i.stockCount,
      minAlertThreshold: i.minAlertThreshold,
    );

BillItem billItemFromFS(FSBillItem i) => BillItem(
      id: i.id,
      type: i.type,
      serviceId: i.serviceId,
      serviceName: i.serviceName,
      inventoryItemId: i.inventoryItemId,
      productName: i.productName,
      quantity: i.quantity,
      unitPrice: i.unitPrice,
      discountAmount: i.discountAmount,
      employeeId: i.employeeId,
      employeeName: i.employeeName,
      calculatedCommission: i.calculatedCommission,
    );

// status defaults to COMPLETED - FS bills have no status field since no
// refund flow exists in either UI yet, matching Bill.fromJson's own
// fallback for a missing status.
Bill billFromFS(FSBill b, {required List<FSBillItem> items, List<FSPayment> payments = const []}) => Bill(
      id: b.id,
      invoiceNumber: b.invoiceNumber,
      customerId: b.customerId,
      customerName: b.customerName,
      branchId: b.branchId,
      subTotal: b.subTotal,
      discountAmount: b.discountAmount,
      taxAmount: b.taxAmount,
      finalAmount: b.finalAmount,
      paymentMethod: b.paymentMethod,
      // What was taken at the counter plus every later settlement, folded
      // into one number so the UI never has to know the ledger exists.
      amountPaid: _round2(b.amountPaid + payments.fold(0.0, (sum, p) => sum + p.amount)),
      status: 'COMPLETED',
      createdAt: b.createdAt,
      items: items.map(billItemFromFS).toList(),
    );

Expense expenseFromFS(FSExpense e) => Expense(
      id: e.id,
      title: e.title,
      amount: e.amount,
      category: e.category,
      date: e.date,
      notes: e.notes,
    );

DiscountRequest discountRequestFromFS(FSDiscountRequest r) => DiscountRequest(
      id: r.id,
      requestedBy: r.requestedBy,
      billId: r.billId,
      requestedDiscount: r.requestedDiscount,
      overridePrice: r.overridePrice,
      reason: r.reason,
      status: r.status,
      authorizedCode: r.authorizedCode,
      createdAt: r.createdAt,
    );

SalesTarget salesTargetFromFS(FSSalesTarget t) => SalesTarget(
      id: t.id,
      employeeId: t.employeeId,
      type: t.type,
      targetValue: t.targetValue,
      progressValue: t.progressValue,
      startDate: t.startDate,
      endDate: t.endDate,
      status: t.status,
    );

SalaryRecord salaryRecordFromFS(FSSalaryRecord r) => SalaryRecord(
      id: r.id,
      employeeId: r.employeeId,
      month: r.month,
      year: r.year,
      baseSalary: r.baseSalary,
      commissionEarned: r.commissionEarned,
      deductions: r.deductions,
      totalPaid: r.totalPaid,
      status: r.status,
    );

CommissionRecord commissionRecordFromFS(FSCommissionRecord c) => CommissionRecord(
      id: c.id,
      employeeId: c.employeeId,
      billItemId: c.billItemId,
      amount: c.amount,
      status: c.status,
      calculatedAt: c.createdAt,
    );

AttendanceRecord attendanceFromFS(FSAttendanceRecord a) => AttendanceRecord(
      id: a.id,
      employeeId: a.employeeId,
      date: a.date,
      clockIn: a.clockIn,
      clockOut: a.clockOut,
      status: a.status,
    );

SalonSettings settingsFromFS(FSSettings s) => SalonSettings(
      salonName: s.salonName,
      phone: s.phone,
      address: s.address,
      gstEnabled: s.gstEnabled,
      gstRate: s.gstRate,
      lateAttendancePenalty: s.lateAttendancePenalty,
    );

// Assembles one AppData from Firestore, replicating every requester-based
// scoping rule the REST backend applies server-side (there's no server here
// to enforce it, so it has to happen client-side, same as the pay
// redaction above): attendance.service.ts, salary.service.ts,
// commission.service.ts and salesTarget.service.ts all resolve a non-owner's
// own EmployeeProfile.id and silently ignore any other employeeId filter;
// discountRequest.service.ts does the same keyed by requestedBy. In the
// Firestore model there's no separate User/EmployeeProfile split - the
// employees/{uid} doc IS both, so the Firebase Auth uid (auth.userId) is
// the one key that plays all of those roles.
Future<AppData> loadAppData(SalonFirestore fs, AuthState auth) async {
  final selfId = auth.isOwner ? null : auth.userId;

  final results = await Future.wait([
    fs.getSettings(),
    fs.listBranches(),
    fs.listEmployees(),
    fs.listCustomers(),
    fs.listServiceCategories(),
    fs.listServices(),
    fs.listInventory(),
    fs.listBills(),
    auth.isOwner ? fs.listExpenses() : Future.value(<FSExpense>[]),
    fs.listDiscountRequests(requestedBy: selfId),
    fs.listSalesTargets(employeeId: selfId),
    fs.listSalaryRecords(employeeId: selfId),
    fs.listCommissions(employeeId: selfId),
    fs.listAttendance(employeeId: selfId),
  ]);

  final settingsFS = results[0] as FSSettings;
  final branchesFS = results[1] as List<FSBranch>;
  final employeesFS = results[2] as List<FSEmployee>;
  final customersFS = results[3] as List<FSCustomer>;
  final categoriesFS = results[4] as List<FSServiceCategory>;
  final servicesFS = results[5] as List<FSService>;
  final inventoryFS = results[6] as List<FSInventoryItem>;
  final billsFS = results[7] as List<FSBill>;
  final expensesFS = results[8] as List<FSExpense>;
  final discountRequestsFS = results[9] as List<FSDiscountRequest>;
  final salesTargetsFS = results[10] as List<FSSalesTarget>;
  final salaryRecordsFS = results[11] as List<FSSalaryRecord>;
  final commissionsFS = results[12] as List<FSCommissionRecord>;
  final attendanceFS = results[13] as List<FSAttendanceRecord>;

  // listBills() doesn't fetch the items subcollection (would be N+1 for
  // every list load otherwise); fetch each bill's items in parallel here,
  // reproducing the REST backend's `include: { items: true }` shape.
  final billItemsByBill = await fs.listBillItemsForBills(billsFS);
  // Settlements recorded after a bill was raised - see recordPayment. Folded
  // into each Bill's amountPaid below so amountDue/paymentStatus are correct
  // everywhere without any caller re-deriving them.
  final paymentsByBill = await fs.listPaymentsForBills(billsFS);
  final bills = <Bill>[
    for (var i = 0; i < billsFS.length; i++)
      billFromFS(
        billsFS[i],
        items: billItemsByBill[billsFS[i].id] ?? const [],
        payments: paymentsByBill[billsFS[i].id] ?? const [],
      ),
  ];

  final employees = employeesFS.map((e) => employeeFromFS(e, canSeePay: auth.isOwner || e.userId == auth.userId)).toList();

  final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final branches = branchesFS.map((b) {
    final branchBills = billsFS.where((bill) => bill.branchId == b.id);
    final monthlyRevenue = _round2(branchBills
        .where((bill) => bill.createdAt != null && !bill.createdAt!.isBefore(startOfMonth))
        .fold(0.0, (sum, bill) => sum + bill.finalAmount));
    return branchFromFS(
      b,
      employeeCount: employeesFS.where((e) => e.branchId == b.id).length,
      // The client directory is salon-wide - one customer can be served at
      // any branch - so a branch's client number is "distinct clients billed
      // here", not "clients that belong to this branch". (It used to count
      // customers/{id}.branchId, which split one shared directory across
      // branches and made the numbers never add up to the real client
      // count.) Scoped to the loaded bills window - see listBills()'s
      // billsPageSize cap.
      customerCount: branchBills.map((bill) => bill.customerId).where((id) => id.isNotEmpty).toSet().length,
      monthlyRevenue: monthlyRevenue,
    );
  }).toList();

  final dashboard = auth.isOwner ? DashboardSummary.fromJson(await fs.getDashboardSummary()) : null;

  final allCustomers = customersFS.map(customerFromFS).toList();

  return AppData(
    branches: branches,
    employees: employees,
    // Split here rather than per-screen so an archived client can't leak back
    // into a picker somewhere - only the Customers tab's Archived filter
    // reads archivedCustomers.
    customers: allCustomers.where((c) => !c.archived).toList(),
    archivedCustomers: allCustomers.where((c) => c.archived).toList(),
    categories: categoriesFS.map(categoryFromFS).toList(),
    services: servicesFS.map(serviceFromFS).toList(),
    inventory: inventoryFS.map(inventoryFromFS).toList(),
    bills: bills,
    expenses: expensesFS.map(expenseFromFS).toList(),
    discountRequests: discountRequestsFS.map(discountRequestFromFS).toList(),
    salesTargets: salesTargetsFS.map(salesTargetFromFS).toList(),
    salaryRecords: salaryRecordsFS.map(salaryRecordFromFS).toList(),
    commissions: commissionsFS.map(commissionRecordFromFS).toList(),
    attendance: attendanceFS.map(attendanceFromFS).toList(),
    dashboard: dashboard,
    settings: settingsFromFS(settingsFS),
  );
}
