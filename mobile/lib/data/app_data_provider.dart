import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/auth_state.dart';
import '../firebase/firestore_app_data.dart';
import '../firebase/firestore_models.dart';
import '../firebase/salon_auth.dart';
import '../firebase/salon_firestore.dart';
import 'app_data.dart';
import 'models.dart';

export 'app_data.dart';

double _round2(num n) => (n * 100).round() / 100;

class AppDataNotifier extends AsyncNotifier<AppData> {
  // Not `late final`: build() reruns on every auth state change (e.g. a
  // logout/login cycle without a full page reload), and re-assigning a
  // `late final` field on a rebuild throws LateInitializationError.
  late SalonFirestore _fs;

  @override
  Future<AppData> build() async {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated) {
      // Nothing to load until logged in; router keeps unauthenticated
      // users on the login screen so this state is never rendered.
      return AppData(
        branches: [],
        employees: [],
        customers: [],
        categories: [],
        services: [],
        inventory: [],
        bills: [],
        expenses: [],
        discountRequests: [],
        salesTargets: [],
        salaryRecords: [],
        commissions: [],
        attendance: [],
        dashboard: null,
        settings: null,
      );
    }

    final app = SalonAuth.currentApp(auth.salonId!);
    if (app == null) throw Exception('No initialized Firebase app for salon "${auth.salonId}"');
    _fs = SalonFirestore(app);

    return _loadAll(auth);
  }

  Future<AppData> _loadAll(AuthState auth) => loadAppData(_fs, auth);

  Future<void> refresh() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;
    state = const AsyncLoading<AppData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _loadAll(auth));
  }

  // --- Branches ---

  Future<void> addBranch({required String name, String? address, String? phone}) async {
    if (await _fs.isBranchNameTaken(name)) {
      throw Exception('A branch with this name already exists');
    }
    final createdFS = await _fs.createBranch(name: name, address: address, phone: phone);
    final created = branchFromFS(createdFS, employeeCount: 0, customerCount: 0, monthlyRevenue: 0);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(branches: [...current.branches, created]));
  }

  Future<void> updateBranch(String id, {String? name, String? address, String? phone, String? managerId, bool? active}) async {
    String? managerName;
    if (managerId != null) {
      final manager = await _fs.getEmployee(managerId);
      if (manager == null) throw Exception('Manager must be an employee in this salon');
      if (manager.branchId != id) throw Exception('Manager must be an employee assigned to this branch');
      managerName = manager.name;
    }
    await _fs.updateBranch(id, {
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (managerId != null) 'managerId': managerId,
      if (active != null) 'active': active,
    });
    // managerName is already resolved above (needed for validation anyway),
    // so the change can be patched into the loaded list without a refetch.
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(branches: [
      for (final b in current.branches)
        if (b.id != id)
          b
        else
          Branch(
            id: b.id,
            name: name ?? b.name,
            address: address ?? b.address,
            phone: phone ?? b.phone,
            active: active ?? b.active,
            managerId: managerId ?? b.managerId,
            managerName: managerId != null ? managerName : b.managerName,
            employeeCount: b.employeeCount,
            customerCount: b.customerCount,
            monthlyRevenue: b.monthlyRevenue,
          ),
    ]));
  }

  Branch _withEmployeeCountDelta(Branch b, int delta) => Branch(
        id: b.id,
        name: b.name,
        address: b.address,
        phone: b.phone,
        active: b.active,
        managerId: b.managerId,
        managerName: b.managerName,
        employeeCount: b.employeeCount + delta,
        customerCount: b.customerCount,
        monthlyRevenue: b.monthlyRevenue,
      );

  // --- Employees ---

  Future<void> addEmployee({
    required String name,
    required String phone,
    required String roleTitle,
    required double baseSalary,
    required double serviceCommissionPct,
    required double productCommissionPct,
    required String email,
    required String password,
    required String branchId,
  }) async {
    final auth = ref.read(authControllerProvider);
    if (await _fs.isPhoneTaken(phone)) {
      throw Exception('An employee with this phone number already exists');
    }
    // Staff are branch-scoped (unlike customers, who are salon-wide), so the
    // branch has to resolve *and* still be open - hiring into a deactivated
    // branch used to be accepted silently and left the new employee on a
    // branch that no longer appears anywhere in the app.
    final branch = await _fs.getBranch(branchId);
    if (branch == null) throw Exception('Branch not found');
    if (!branch.active) throw Exception('"${branch.name}" is deactivated - reactivate it before assigning staff');
    final ownerApp = SalonAuth.currentApp(auth.salonId!);
    if (ownerApp == null) throw Exception('No initialized Firebase app for salon "${auth.salonId}"');
    // Creating the Auth account happens on a throwaway secondary app (see
    // SalonAuth.createEmployeeAccount) so the owner's own session here is
    // untouched; this client then writes the profile while still
    // authenticated as owner, which is what firestore.rules requires.
    final uid = await SalonAuth.createEmployeeAccount(ownerApp, email, password);
    final current = state.value;
    final branchName = current?.branchById(branchId)?.name;
    final fsEmployee = FSEmployee(
      id: uid,
      userId: uid,
      email: email,
      name: name,
      phone: phone,
      roleTitle: roleTitle,
      role: 'EMPLOYEE',
      active: true,
      baseSalary: baseSalary,
      serviceCommissionPct: serviceCommissionPct,
      productCommissionPct: productCommissionPct,
      branchId: branchId,
      branchName: branchName,
    );
    await _fs.writeEmployeeProfile(uid, fsEmployee);
    if (current == null) return;
    // addEmployee is owner-only (firestore.rules), so the actor here is
    // always the owner and can see the new hire's own pay fields.
    final created = employeeFromFS(fsEmployee, canSeePay: true);
    state = AsyncData(current.copyWith(
      employees: [...current.employees, created],
      branches: [for (final b in current.branches) b.id == branchId ? _withEmployeeCountDelta(b, 1) : b],
    ));
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> changes) async {
    final newBranchId = changes['branchId'] as String?;
    if (newBranchId != null) {
      final branch = await _fs.getBranch(newBranchId);
      if (branch == null) throw Exception('Branch not found');
      // Same rule as addEmployee - you can move staff *out* of a deactivated
      // branch, never into one.
      final existingBranchId = state.value?.employeeById(id)?.branchId;
      if (!branch.active && newBranchId != existingBranchId) {
        throw Exception('"${branch.name}" is deactivated - reactivate it before assigning staff');
      }
    }
    await _fs.updateEmployee(id, changes);
    final current = state.value;
    if (current == null) return;
    final existing = current.employeeById(id);
    if (existing == null) {
      // Not in the already-loaded roster (shouldn't happen) - fall back to
      // a full reload rather than silently dropping the change from state.
      await refresh();
      return;
    }
    final branchChanged = newBranchId != null && newBranchId != existing.branchId;
    final updated = EmployeeProfile(
      id: existing.id,
      userId: existing.userId,
      email: existing.email,
      name: changes['name'] as String? ?? existing.name,
      phone: changes['phone'] as String? ?? existing.phone,
      roleTitle: changes['roleTitle'] as String? ?? existing.roleTitle,
      active: changes['active'] as bool? ?? existing.active,
      baseSalary: (changes['baseSalary'] as num?)?.toDouble() ?? existing.baseSalary,
      serviceCommissionPct: (changes['serviceCommissionPct'] as num?)?.toDouble() ?? existing.serviceCommissionPct,
      productCommissionPct: (changes['productCommissionPct'] as num?)?.toDouble() ?? existing.productCommissionPct,
      branchId: newBranchId ?? existing.branchId,
      branchName: branchChanged ? current.branchById(newBranchId)?.name : existing.branchName,
    );
    state = AsyncData(current.copyWith(
      employees: [for (final e in current.employees) e.id == id ? updated : e],
      branches: !branchChanged
          ? current.branches
          : [
              for (final b in current.branches)
                if (b.id == existing.branchId)
                  _withEmployeeCountDelta(b, -1)
                else if (b.id == newBranchId)
                  _withEmployeeCountDelta(b, 1)
                else
                  b,
            ],
    ));
  }

  // There's no Admin SDK to set another user's password client-side, so this
  // sends Firebase's own reset-link email instead. See salon_auth.dart's
  // sendPasswordResetEmail.
  Future<void> resetEmployeePassword(String id) async {
    final auth = ref.read(authControllerProvider);
    final email = state.value?.employeeById(id)?.email;
    if (email == null || email.isEmpty) throw Exception('Employee not found');
    final app = SalonAuth.currentApp(auth.salonId!);
    if (app == null) throw Exception('No initialized Firebase app for salon "${auth.salonId}"');
    await SalonAuth.sendPasswordResetEmail(app, email);
  }

  // --- Customers ---

  // The client directory is deliberately salon-wide: one customer record is
  // visible and billable at every branch, so this takes no branchId and
  // never asks the caller for one. `branchId` stays on the document only as
  // "where they were first registered" (empty when unknown) - nothing reads
  // it to decide what a branch can see. A branch's client figure comes from
  // its bills instead (see firestore_app_data.dart).
  Future<void> addCustomer({
    required String name,
    required String phone,
    String? email,
    String? gender,
    bool? isVip,
    String? registeredAtBranchId,
  }) async {
    if (await _fs.isCustomerPhoneTaken(phone)) {
      throw Exception('A customer with this phone number already exists');
    }
    final createdFS = await _fs.createCustomer(FSCustomer(
      id: '',
      name: name,
      phone: phone,
      email: email,
      gender: gender,
      isVip: isVip ?? false,
      branchId: registeredAtBranchId ?? '',
    ));
    final created = customerFromFS(createdFS);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(customers: [created, ...current.customers]));
  }

  // firestore.rules blocks customer deletes on purpose ("customer history
  // should never disappear"), so removing a client is an archive flag, not a
  // delete: the doc and every bill that references it stay put, the client
  // just stops appearing anywhere in the app (see firestore_app_data.dart,
  // which filters archived rows out of the snapshot). Reversible from the
  // Firebase Console by setting archived back to false.
  Future<void> archiveCustomer(String id) async {
    final current = state.value;
    if (current == null) throw Exception('Not ready yet - try again in a moment');
    final match = current.customers.where((c) => c.id == id);
    if (match.isEmpty) throw Exception('Customer not found');

    await _fs.updateCustomer(id, {'archived': true});
    state = AsyncData(current.copyWith(
      customers: current.customers.where((c) => c.id != id).toList(),
      archivedCustomers: [match.first, ...current.archivedCustomers],
    ));
  }

  // The inverse - puts a client back in the directory (and back in every
  // picker) without touching anything else on their record.
  Future<void> unarchiveCustomer(String id) async {
    final current = state.value;
    if (current == null) throw Exception('Not ready yet - try again in a moment');
    final match = current.archivedCustomers.where((c) => c.id == id);
    if (match.isEmpty) throw Exception('Customer not found');

    await _fs.updateCustomer(id, {'archived': false});
    state = AsyncData(current.copyWith(
      archivedCustomers: current.archivedCustomers.where((c) => c.id != id).toList(),
      customers: [match.first, ...current.customers],
    ));
  }

  // On-demand, not part of AppData - a customer's full visit history isn't
  // needed until their profile is actually opened, and pulling it from the
  // capped `bills` list in AppData would silently miss older visits once a
  // salon has more than listBills()'s page size in total.
  Future<List<Bill>> loadBillsForCustomer(String customerId) async {
    final billsFS = await _fs.listBillsForCustomer(customerId);
    final itemsByBill = await Future.wait(billsFS.map((b) => _fs.listBillItems(b.id)));
    return [for (var i = 0; i < billsFS.length; i++) billFromFS(billsFS[i], items: itemsByBill[i])];
  }

  // --- Catalog ---

  Future<ServiceCategory> addServiceCategory(String name) async {
    if (await _fs.isServiceCategoryNameTaken(name)) {
      throw Exception('A category with this name already exists');
    }
    final createdFS = await _fs.createServiceCategory(name);
    final created = categoryFromFS(createdFS);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(categories: [...current.categories, created]));
    return created;
  }

  Future<void> addService({required String name, required double price, required String categoryId}) async {
    final current = state.value;
    final categoryMatch = current?.categories.where((c) => c.id == categoryId) ?? const Iterable.empty();
    if (categoryMatch.isEmpty) throw Exception('Service category not found');
    if (await _fs.isServiceNameTaken(name)) {
      throw Exception('A service with this name already exists');
    }
    final categoryName = categoryMatch.first.name;
    final createdFS = await _fs.createService(FSService(id: '', name: name, price: price, categoryId: categoryId, categoryName: categoryName));
    final created = serviceFromFS(createdFS);
    if (current != null) state = AsyncData(current.copyWith(services: [...current.services, created]));
  }

  Future<void> addInventoryItem({
    required String sku,
    required String name,
    required String category,
    required double price,
    required double costPrice,
    int? stockCount,
    int? minAlertThreshold,
  }) async {
    if (await _fs.isSkuTaken(sku)) {
      throw Exception('An inventory item with this SKU already exists');
    }
    final createdFS = await _fs.createInventoryItem(FSInventoryItem(
      id: '',
      sku: sku,
      name: name,
      category: category,
      price: price,
      costPrice: costPrice,
      stockCount: stockCount ?? 0,
      minAlertThreshold: minAlertThreshold ?? 5,
    ));
    final created = inventoryFromFS(createdFS);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(inventory: [...current.inventory, created]));
  }

  Future<void> updateInventoryStock(String id, int newStock) async {
    await _fs.updateInventoryItem(id, {'stockCount': newStock});
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(
        inventory: current.inventory.map((i) {
          if (i.id != id) return i;
          return InventoryItem(
            id: i.id,
            sku: i.sku,
            name: i.name,
            category: i.category,
            price: i.price,
            costPrice: i.costPrice,
            stockCount: newStock,
            minAlertThreshold: i.minAlertThreshold,
          );
        }).toList(),
      ));
    }
  }

  // --- Billing ---

  Future<Bill> createBill({
    required String customerId,
    required String branchId,
    required String paymentMethod,
    double? discountAmount,
    required List<BillItemInput> items,
  }) async {
    final auth = ref.read(authControllerProvider);
    final current = state.value;
    if (current == null) throw Exception('Not ready yet - try again in a moment');

    final customerMatch = current.customers.where((c) => c.id == customerId);
    if (customerMatch.isEmpty) throw Exception('Customer not found');
    if (current.branchById(branchId) == null) throw Exception('Branch not found');

    // Resolve catalog price, employee commission rate, and stock
    // availability for every item up front, exactly like bill.service.ts's
    // BillService.create used to do before its transaction - so a bad input
    // fails fast with a clear message instead of partway through the
    // Firestore transaction.
    final drafts = <BillItemDraft>[];
    for (final item in items) {
      final employee = current.employeeById(item.employeeId);
      if (employee == null || !employee.active) throw Exception('Employee not found or inactive');

      double catalogPrice;
      String? serviceName;
      String? productName;
      final quantity = item.quantity ?? 1;

      if (item.type == 'SERVICE') {
        final match = current.services.where((s) => s.id == item.serviceId);
        if (match.isEmpty) throw Exception('Service not found');
        catalogPrice = match.first.price;
        serviceName = match.first.name;
      } else {
        final match = current.inventory.where((i) => i.id == item.inventoryItemId);
        if (match.isEmpty) throw Exception('Inventory item not found');
        if (match.first.stockCount < quantity) {
          throw Exception('Insufficient stock for ${match.first.name} (have ${match.first.stockCount}, need $quantity)');
        }
        catalogPrice = match.first.price;
        productName = match.first.name;
      }

      final unitPrice = item.unitPrice ?? catalogPrice;
      if (item.unitPrice != null && item.unitPrice != catalogPrice && (item.priceOverrideReason == null || item.priceOverrideReason!.isEmpty)) {
        throw Exception('priceOverrideReason is required to override the catalog price${productName != null ? ' for $productName' : ''}');
      }

      drafts.add(BillItemDraft(
        type: item.type,
        serviceId: item.serviceId,
        serviceName: serviceName,
        inventoryItemId: item.inventoryItemId,
        productName: productName,
        employeeId: item.employeeId,
        employeeName: employee.name,
        quantity: quantity,
        unitPrice: unitPrice,
        discountAmount: item.discountAmount ?? 0,
        commissionPct: item.type == 'SERVICE' ? employee.serviceCommissionPct : employee.productCommissionPct,
      ));
    }

    final createdFS = await _fs.createBill(
      customerId: customerId,
      customerName: customerMatch.first.name,
      branchId: branchId,
      paymentMethod: paymentMethod,
      createdBy: auth.userId!,
      // GST is opt-in: a salon charges no tax until the owner sets a rate
      // in Settings, so the fallback here is 0, not 18.
      gstRate: current.settings?.gstRate ?? 0,
      billDiscountAmount: discountAmount ?? 0,
      items: drafts,
    );
    // The transaction's own return value never has createdAt set (that's
    // FieldValue.serverTimestamp(), which only resolves once read back) -
    // one extra doc get() resolves it without reloading the whole bills list.
    final freshBillFS = await _fs.getBill(createdFS.id) ?? createdFS;
    final itemsFS = await _fs.listBillItems(createdFS.id);
    final created = billFromFS(freshBillFS, items: itemsFS);

    // A bill also touches customer stats, stock, commissions, and sales
    // targets (see createBill's transaction in salon_firestore.dart). Rather
    // than reloading the entire salon - up to billsPageSize bills plus one
    // items-subcollection read *each*, on every single bill - patch the new
    // bill and the customer's denormalized stats in directly, and only
    // refetch the handful of small collections a bill can actually change.
    final selfId = auth.isOwner ? null : auth.userId;
    final results = await Future.wait([
      _fs.listInventory(),
      _fs.listSalesTargets(employeeId: selfId),
      _fs.listCommissions(employeeId: selfId),
      auth.isOwner ? _fs.getDashboardSummary() : Future.value(<String, dynamic>{}),
    ]);
    final inventory = (results[0] as List<FSInventoryItem>).map(inventoryFromFS).toList();
    final salesTargets = (results[1] as List<FSSalesTarget>).map(salesTargetFromFS).toList();
    final commissions = (results[2] as List<FSCommissionRecord>).map(commissionRecordFromFS).toList();

    final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final billCountsThisMonth = created.createdAt == null || !created.createdAt!.isBefore(startOfMonth);
    // Re-read state.value rather than reusing the `current` snapshot from
    // before all the awaits above (the transaction plus four more reads) -
    // patching a stale base could silently clobber some other mutation that
    // completed in the meantime. inventory/salesTargets/commissions came
    // straight from Firestore just now so they're never stale either way.
    final latest = state.value ?? current;
    final dashboard = auth.isOwner ? DashboardSummary.fromJson(results[3] as Map<String, dynamic>) : latest.dashboard;
    state = AsyncData(latest.copyWith(
      bills: [created, ...latest.bills],
      customers: [
        for (final c in latest.customers)
          if (c.id != customerId)
            c
          else
            Customer(
              id: c.id,
              name: c.name,
              phone: c.phone,
              email: c.email,
              gender: c.gender,
              notes: c.notes,
              isVip: c.isVip,
              branchId: c.branchId,
              createdAt: c.createdAt,
              visitCount: c.visitCount + 1,
              totalSpent: _round2(c.totalSpent + created.finalAmount),
              lastVisitAt: created.createdAt ?? DateTime.now(),
            ),
      ],
      branches: [
        for (final b in latest.branches)
          if (b.id == branchId && billCountsThisMonth)
            Branch(
              id: b.id,
              name: b.name,
              address: b.address,
              phone: b.phone,
              active: b.active,
              managerId: b.managerId,
              managerName: b.managerName,
              employeeCount: b.employeeCount,
              customerCount: b.customerCount,
              monthlyRevenue: _round2(b.monthlyRevenue + created.finalAmount),
            )
          else
            b,
      ],
      inventory: inventory,
      salesTargets: salesTargets,
      commissions: commissions,
      dashboard: dashboard,
    ));
    return created;
  }

  // --- Expenses ---

  Future<void> addExpense({required String title, required double amount, required String category, required String date, String? notes}) async {
    final createdFS = await _fs.createExpense(FSExpense(id: '', title: title, amount: amount, category: category, date: DateTime.parse(date), notes: notes));
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(expenses: [expenseFromFS(createdFS), ...current.expenses]));
  }

  // --- Discount requests ---

  Future<void> requestDiscount({String? billId, required double requestedDiscount, double? overridePrice, required String reason}) async {
    final auth = ref.read(authControllerProvider);
    final requestedBy = auth.userId!;
    final createdFS = await _fs.createDiscountRequest(FSDiscountRequest(
      id: '',
      requestedBy: requestedBy,
      billId: billId,
      requestedDiscount: requestedDiscount,
      overridePrice: overridePrice,
      reason: reason,
      status: 'PENDING',
    ));
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(discountRequests: [discountRequestFromFS(createdFS), ...current.discountRequests]));
  }

  Future<void> approveDiscountRequest(String id) async {
    final resolved = await _fs.resolveDiscountRequest(id, approve: true);
    _patchDiscountRequest(resolved);
  }

  Future<void> rejectDiscountRequest(String id) async {
    final resolved = await _fs.resolveDiscountRequest(id, approve: false);
    _patchDiscountRequest(resolved);
  }

  void _patchDiscountRequest(FSDiscountRequest resolved) {
    final current = state.value;
    if (current == null) return;
    final updated = discountRequestFromFS(resolved);
    state = AsyncData(current.copyWith(discountRequests: [for (final r in current.discountRequests) r.id == updated.id ? updated : r]));
  }

  // --- Sales targets ---

  Future<void> addSalesTarget({
    required String employeeId,
    required String type,
    required double targetValue,
    required String startDate,
    required String endDate,
  }) async {
    if (state.value?.employeeById(employeeId) == null) {
      throw Exception('Employee not found');
    }
    final createdFS = await _fs.createSalesTarget(FSSalesTarget(
      id: '',
      employeeId: employeeId,
      type: type,
      targetValue: targetValue,
      progressValue: 0,
      startDate: DateTime.parse(startDate),
      endDate: DateTime.parse(endDate),
      status: 'ACTIVE',
    ));
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(salesTargets: [...current.salesTargets, salesTargetFromFS(createdFS)]));
  }

  // --- Salary ---

  // Unlike the mutations above, generateSalary legitimately fans out across
  // every active employee at once (a payroll run) and flips a batch of
  // commissionRecords to PAID as a side effect - low-frequency (monthly) and
  // correctness-sensitive enough that re-deriving its exact effect on
  // `commissions` client-side isn't worth the risk of drifting from what
  // salon_firestore.dart's transaction actually did. Refetching stays the
  // simplest way to guarantee the two agree.
  Future<void> generateSalary({required int month, required int year, String? employeeId}) async {
    await _fs.generateSalary(month: month, year: year, employeeId: employeeId);
    await refresh();
  }

  Future<void> markSalaryPaid(String id) async {
    await _fs.markSalaryPaid(id);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(salaryRecords: [
      for (final r in current.salaryRecords)
        if (r.id != id)
          r
        else
          SalaryRecord(
            id: r.id,
            employeeId: r.employeeId,
            month: r.month,
            year: r.year,
            baseSalary: r.baseSalary,
            commissionEarned: r.commissionEarned,
            deductions: r.deductions,
            totalPaid: r.totalPaid,
            status: 'PAID',
          ),
    ]));
  }

  // --- Commissions ---

  Future<void> markCommissionPaid(String id) async {
    await _fs.markCommissionPaid(id);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(commissions: [
      for (final c in current.commissions)
        if (c.id != id)
          c
        else
          CommissionRecord(id: c.id, employeeId: c.employeeId, billItemId: c.billItemId, amount: c.amount, status: 'PAID', calculatedAt: c.calculatedAt),
    ]));
  }

  // --- Attendance ---

  Future<void> clockIn({double? lat, double? lng}) async {
    final auth = ref.read(authControllerProvider);
    // FSAttendanceRecord tracks no lat/lng - dropped silently rather than
    // expanding the Firestore schema for a field neither UI screen
    // currently surfaces.
    final recordFS = await _fs.clockIn(auth.userId!);
    _patchAttendance(recordFS);
  }

  Future<void> clockOut({double? lat, double? lng}) async {
    final auth = ref.read(authControllerProvider);
    final recordFS = await _fs.clockOut(auth.userId!);
    _patchAttendance(recordFS);
  }

  Future<void> markAttendance({required String employeeId, required String date, required String status, String? notes}) async {
    if (state.value?.employeeById(employeeId) == null) {
      throw Exception('Employee not found');
    }
    final recordFS = await _fs.markAttendance(employeeId: employeeId, date: DateTime.parse(date), status: status);
    _patchAttendance(recordFS);
  }

  // clockIn/clockOut/markAttendance each touch exactly one doc id
  // ("{employeeId}_{yyyy-MM-dd}") - upsert it into the loaded list instead of
  // reloading everything else (bills, employees, inventory, ...) just
  // because someone clocked in. This is the single most frequent mutation
  // in the app (every employee, twice a day), so it matters the most here.
  void _patchAttendance(FSAttendanceRecord recordFS) {
    final current = state.value;
    if (current == null) return;
    final updated = attendanceFromFS(recordFS);
    final withoutOld = current.attendance.where((a) => a.id != updated.id);
    state = AsyncData(current.copyWith(attendance: [updated, ...withoutOld]));
  }

  // --- Settings ---

  Future<void> updateSettings(Map<String, dynamic> changes) async {
    await _fs.updateSettings(changes);
    final updated = settingsFromFS(await _fs.getSettings());
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(settings: updated));
  }
}

final appDataProvider = AsyncNotifierProvider<AppDataNotifier, AppData>(AppDataNotifier.new);
