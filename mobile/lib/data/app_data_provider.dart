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
    if (managerId != null) {
      final manager = await _fs.getEmployee(managerId);
      if (manager == null) throw Exception('Manager must be an employee in this salon');
      if (manager.branchId != id) throw Exception('Manager must be an employee assigned to this branch');
    }
    await _fs.updateBranch(id, {
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (managerId != null) 'managerId': managerId,
      if (active != null) 'active': active,
    });
    // managerName needs joining against the employees list - simplest to
    // just refetch rather than re-resolve it client-side here too.
    await refresh();
  }

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
    if (await _fs.getBranch(branchId) == null) {
      throw Exception('Branch not found');
    }
    final ownerApp = SalonAuth.currentApp(auth.salonId!);
    if (ownerApp == null) throw Exception('No initialized Firebase app for salon "${auth.salonId}"');
    // Creating the Auth account happens on a throwaway secondary app (see
    // SalonAuth.createEmployeeAccount) so the owner's own session here is
    // untouched; this client then writes the profile while still
    // authenticated as owner, which is what firestore.rules requires.
    final uid = await SalonAuth.createEmployeeAccount(ownerApp, email, password);
    final branchName = state.value?.branchById(branchId)?.name;
    await _fs.writeEmployeeProfile(
      uid,
      FSEmployee(
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
      ),
    );
    await refresh();
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> changes) async {
    final newBranchId = changes['branchId'] as String?;
    if (newBranchId != null && await _fs.getBranch(newBranchId) == null) {
      throw Exception('Branch not found');
    }
    await _fs.updateEmployee(id, changes);
    await refresh();
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

  Future<void> addCustomer({
    required String name,
    required String phone,
    String? email,
    String? gender,
    bool? isVip,
    required String branchId,
  }) async {
    if (await _fs.isCustomerPhoneTaken(phone)) {
      throw Exception('A customer with this phone number already exists');
    }
    if (await _fs.getBranch(branchId) == null) {
      throw Exception('Branch not found');
    }
    final createdFS = await _fs.createCustomer(FSCustomer(
      id: '',
      name: name,
      phone: phone,
      email: email,
      gender: gender,
      isVip: isVip ?? false,
      branchId: branchId,
    ));
    final created = customerFromFS(createdFS);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(customers: [created, ...current.customers]));
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
      gstRate: current.settings?.gstRate ?? 18,
      billDiscountAmount: discountAmount ?? 0,
      items: drafts,
    );
    final itemsFS = await _fs.listBillItems(createdFS.id);
    final created = billFromFS(createdFS, items: itemsFS);
    // A bill touches sales, stock, commissions, and targets all at once -
    // simplest to just refetch everything rather than hand-patch five
    // different lists client-side.
    await refresh();
    return created;
  }

  // --- Expenses ---

  Future<void> addExpense({required String title, required double amount, required String category, required String date, String? notes}) async {
    await _fs.createExpense(FSExpense(id: '', title: title, amount: amount, category: category, date: DateTime.parse(date), notes: notes));
    // createExpense() (salon_firestore.dart) doesn't hand back the written
    // doc's real id, so refetch rather than patch in a fake one.
    await refresh();
  }

  // --- Discount requests ---

  Future<void> requestDiscount({String? billId, required double requestedDiscount, double? overridePrice, required String reason}) async {
    final auth = ref.read(authControllerProvider);
    final requestedBy = auth.userId!;
    await _fs.createDiscountRequest(FSDiscountRequest(
      id: '',
      requestedBy: requestedBy,
      billId: billId,
      requestedDiscount: requestedDiscount,
      overridePrice: overridePrice,
      reason: reason,
      status: 'PENDING',
    ));
    await refresh();
  }

  Future<void> approveDiscountRequest(String id) async {
    await _fs.resolveDiscountRequest(id, approve: true);
    await refresh();
  }

  Future<void> rejectDiscountRequest(String id) async {
    await _fs.resolveDiscountRequest(id, approve: false);
    await refresh();
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
    await _fs.createSalesTarget(FSSalesTarget(
      id: '',
      employeeId: employeeId,
      type: type,
      targetValue: targetValue,
      progressValue: 0,
      startDate: DateTime.parse(startDate),
      endDate: DateTime.parse(endDate),
      status: 'ACTIVE',
    ));
    await refresh();
  }

  // --- Salary ---

  Future<void> generateSalary({required int month, required int year, String? employeeId}) async {
    await _fs.generateSalary(month: month, year: year, employeeId: employeeId);
    await refresh();
  }

  Future<void> markSalaryPaid(String id) async {
    await _fs.markSalaryPaid(id);
    await refresh();
  }

  // --- Commissions ---

  Future<void> markCommissionPaid(String id) async {
    await _fs.markCommissionPaid(id);
    await refresh();
  }

  // --- Attendance ---

  Future<void> clockIn({double? lat, double? lng}) async {
    final auth = ref.read(authControllerProvider);
    // FSAttendanceRecord tracks no lat/lng - dropped silently rather than
    // expanding the Firestore schema for a field neither UI screen
    // currently surfaces.
    await _fs.clockIn(auth.userId!);
    await refresh();
  }

  Future<void> clockOut({double? lat, double? lng}) async {
    final auth = ref.read(authControllerProvider);
    await _fs.clockOut(auth.userId!);
    await refresh();
  }

  Future<void> markAttendance({required String employeeId, required String date, required String status, String? notes}) async {
    if (state.value?.employeeById(employeeId) == null) {
      throw Exception('Employee not found');
    }
    await _fs.markAttendance(employeeId: employeeId, date: DateTime.parse(date), status: status);
    await refresh();
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
