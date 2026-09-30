import '../data/app_data.dart';
import '../data/models.dart';
import '../features/auth/auth_state.dart';
import 'firestore_models.dart';
import 'salon_firestore.dart';

double _round2(num n) => (n * 100).round() / 100;

/// "How many staff are in today", counted the way dashboard.service.ts did:
/// LATE still means they turned up.
///
/// Two entry points because the figure is needed once per shape - from the
/// raw FS rows during a load, and from the loaded snapshot when patching
/// after a bill - and both feed [SalonFirestore.getDashboardSummary], so a
/// single rule here is what stops the two paths reporting different numbers
/// for the same day.
bool _countsAsInToday(DateTime? date, String status) {
  if (date == null) return false;
  if (status != 'PRESENT' && status != 'LATE') return false;
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

int todayAttendanceCountFS(List<FSAttendanceRecord> attendance) =>
    attendance.where((a) => _countsAsInToday(a.date, a.status)).length;

int todayAttendanceCountOf(List<AttendanceRecord> attendance) =>
    attendance.where((a) => _countsAsInToday(a.date, a.status)).length;

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
      lat: b.lat,
      lng: b.lng,
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
      createdById: c.createdById,
      createdByName: c.createdByName,
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
      confirmed: a.confirmed,
      confirmedBy: a.confirmedBy,
      clockInLat: a.clockInLat,
      clockInLng: a.clockInLng,
      clockInLocationNote: a.clockInLocationNote,
    );

SalonSettings settingsFromFS(FSSettings s) => SalonSettings(
      salonName: s.salonName,
      phone: s.phone,
      address: s.address,
      gstEnabled: s.gstEnabled,
      gstRate: s.gstRate,
      lateAttendancePenalty: s.lateAttendancePenalty,
      dailyRevenueTarget: s.dailyRevenueTarget,
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
/// [preloadedSettings] is the settings doc sign-in already fetched, when this
/// is the first load of a session - see AuthController.consumeInitialSettings.
/// A refresh passes null and reads it fresh like everything else.
Future<AppData> loadAppData(SalonFirestore fs, AuthState auth, {FSSettings? preloadedSettings}) async {
  final selfId = auth.isOwner ? null : auth.userId;

  final results = await Future.wait([
    preloadedSettings == null ? fs.getSettings() : Future.value(preloadedSettings),
    fs.listBranches(),
    fs.listEmployees(),
    fs.listCustomers(),
    fs.listServiceCategories(),
    fs.listServices(),
    fs.listInventory(),
    fs.listBills(),
    // Expenses are deliberately absent: they belong to one screen and load
    // when it opens (see data/expenses_provider.dart), not on every sign-in.
    // Owners take the count only - ten of the twelve places that read these
    // want a badge number, and the Discounts screen loads the documents when
    // it opens (see data/discount_requests_provider.dart). Staff keep the
    // list: theirs is filtered to their own, so it is a handful of docs, and
    // their Discounts tab needs them anyway.
    auth.isOwner ? Future.value(<FSDiscountRequest>[]) : fs.listDiscountRequests(requestedBy: selfId),
    auth.isOwner ? fs.countPendingDiscountRequests() : Future.value(-1),
    // One aggregate query, owner only - staff neither approve these nor
    // carry a badge for them, so they skip it entirely.
    auth.isOwner ? fs.countPendingPaymentRequests() : Future.value(0),
    fs.listSalesTargets(employeeId: selfId),
    // Salary records are absent for the same reason as expenses, and more
    // urgently: the query is uncapped, so it grows every month forever.
    // See data/salary_provider.dart.
    fs.listPendingCommissions(employeeId: selfId),
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
  final discountRequestsFS = results[8] as List<FSDiscountRequest>;
  final pendingDiscountsCounted = results[9] as int;
  final pendingPaymentRequestsCounted = results[10] as int;
  final salesTargetsFS = results[11] as List<FSSalesTarget>;
  final commissionsFS = results[12] as List<FSCommissionRecord>;
  final attendanceFS = results[13] as List<FSAttendanceRecord>;

  // -1 is the staff sentinel from the wait above: derive it from the list
  // they already hold rather than spending a second query on it.
  final pendingDiscountCount = pendingDiscountsCounted >= 0
      ? pendingDiscountsCounted
      : discountRequestsFS.where((r) => r.status == 'PENDING').length;

  // listBills() doesn't fetch the items subcollection (would be N+1 for
  // every list load otherwise); fetch each bill's items in parallel here,
  // reproducing the REST backend's `include: { items: true }` shape.
  //
  // Items, payments and the dashboard are independent of each other and only
  // items/payments even need billsFS, so they go out together - awaiting them
  // one after another made the load four serial round-trip phases where two
  // do. Settlements recorded after a bill was raised (see recordPayment) get
  // folded into each Bill's amountPaid below, so amountDue/paymentStatus are
  // correct everywhere without any caller re-deriving them.
  // Started together, awaited one by one: they're all in flight from the
  // moment the futures are created, so this is concurrent without the
  // heterogeneous Future.wait that would erase their types to Object.
  final itemsFuture = fs.listBillItemsForBills(billsFS);
  final paymentsFuture = fs.listPaymentsForBills(billsFS);
  final dashboardFuture = auth.isOwner
      ? fs.getDashboardSummary(
          // Derived from the lists already fetched above instead of
          // re-querying the same three collections - see the note on
          // getDashboardSummary itself.
          todayAttendanceCount: todayAttendanceCountFS(attendanceFS),
          pendingDiscountRequests: pendingDiscountCount,
          lowStockItemCount: inventoryFS.where((i) => i.isLowStock).length,
        )
      : null;

  final billItemsByBill = await itemsFuture;
  final paymentsByBill = await paymentsFuture;
  final dashboardJson = await dashboardFuture;
  final dashboard = dashboardJson == null ? null : DashboardSummary.fromJson(dashboardJson);

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
    discountRequests: discountRequestsFS.map(discountRequestFromFS).toList(),
    pendingPaymentRequestCount: pendingPaymentRequestsCounted,
    pendingDiscountCount: pendingDiscountCount,
    salesTargets: salesTargetsFS.map(salesTargetFromFS).toList(),
    commissions: commissionsFS.map(commissionRecordFromFS).toList(),
    attendance: attendanceFS.map(attendanceFromFS).toList(),
    dashboard: dashboard,
    settings: settingsFromFS(settingsFS),
  );
}
