import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/auth_state.dart';
import 'models.dart';
import 'repository.dart';

class AppData {
  final List<Branch> branches;
  final List<EmployeeProfile> employees;
  final List<Customer> customers;
  final List<ServiceCategory> categories;
  final List<SalonService> services;
  final List<InventoryItem> inventory;
  final List<Bill> bills;
  final List<Expense> expenses;
  final List<DiscountRequest> discountRequests;
  final List<SalesTarget> salesTargets;
  final List<SalaryRecord> salaryRecords;
  final List<CommissionRecord> commissions;
  final List<AttendanceRecord> attendance;
  final DashboardSummary? dashboard;
  final SalonSettings? settings;

  AppData({
    required this.branches,
    required this.employees,
    required this.customers,
    required this.categories,
    required this.services,
    required this.inventory,
    required this.bills,
    required this.expenses,
    required this.discountRequests,
    required this.salesTargets,
    required this.salaryRecords,
    required this.commissions,
    required this.attendance,
    required this.dashboard,
    required this.settings,
  });

  // Resolves a name for display without an extra network round trip -
  // most list screens already have the full employees/customers lists
  // loaded, so a local lookup is both simpler and faster than joining
  // server-side for every reference (discount requester, bill customer).
  String employeeNameForUserId(String userId) {
    final match = employees.where((e) => e.userId == userId);
    return match.isEmpty ? 'Unknown' : match.first.name;
  }

  EmployeeProfile? employeeById(String id) {
    final match = employees.where((e) => e.id == id);
    return match.isEmpty ? null : match.first;
  }

  Branch? branchById(String id) {
    final match = branches.where((b) => b.id == id);
    return match.isEmpty ? null : match.first;
  }

  AppData copyWith({
    List<Branch>? branches,
    List<EmployeeProfile>? employees,
    List<Customer>? customers,
    List<ServiceCategory>? categories,
    List<SalonService>? services,
    List<InventoryItem>? inventory,
    List<Bill>? bills,
    List<Expense>? expenses,
    List<DiscountRequest>? discountRequests,
    List<SalesTarget>? salesTargets,
    List<SalaryRecord>? salaryRecords,
    List<CommissionRecord>? commissions,
    List<AttendanceRecord>? attendance,
    DashboardSummary? dashboard,
    SalonSettings? settings,
  }) {
    return AppData(
      branches: branches ?? this.branches,
      employees: employees ?? this.employees,
      customers: customers ?? this.customers,
      categories: categories ?? this.categories,
      services: services ?? this.services,
      inventory: inventory ?? this.inventory,
      bills: bills ?? this.bills,
      expenses: expenses ?? this.expenses,
      discountRequests: discountRequests ?? this.discountRequests,
      salesTargets: salesTargets ?? this.salesTargets,
      salaryRecords: salaryRecords ?? this.salaryRecords,
      commissions: commissions ?? this.commissions,
      attendance: attendance ?? this.attendance,
      dashboard: dashboard ?? this.dashboard,
      settings: settings ?? this.settings,
    );
  }
}

class AppDataNotifier extends AsyncNotifier<AppData> {
  late final BranchApi _branchApi;
  late final EmployeeApi _employeeApi;
  late final CustomerApi _customerApi;
  late final CatalogApi _catalogApi;
  late final BillApi _billApi;
  late final ExpenseApi _expenseApi;
  late final DiscountRequestApi _discountRequestApi;
  late final SalesTargetApi _salesTargetApi;
  late final SalaryApi _salaryApi;
  late final CommissionApi _commissionApi;
  late final AttendanceApi _attendanceApi;
  late final DashboardApi _dashboardApi;
  late final SettingsApi _settingsApi;

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

    final client = ref.read(apiClientProvider);
    _branchApi = BranchApi(client);
    _employeeApi = EmployeeApi(client);
    _customerApi = CustomerApi(client);
    _catalogApi = CatalogApi(client);
    _billApi = BillApi(client);
    _expenseApi = ExpenseApi(client);
    _discountRequestApi = DiscountRequestApi(client);
    _salesTargetApi = SalesTargetApi(client);
    _salaryApi = SalaryApi(client);
    _commissionApi = CommissionApi(client);
    _attendanceApi = AttendanceApi(client);
    _dashboardApi = DashboardApi(client);
    _settingsApi = SettingsApi(client);

    return _loadAll(auth);
  }

  Future<AppData> _loadAll(AuthState auth) async {
    final results = await Future.wait([
      _branchApi.list(),
      _employeeApi.list(),
      _customerApi.list(),
      _catalogApi.listCategories(),
      _catalogApi.listServices(),
      _catalogApi.listInventory(),
      _billApi.list(),
      auth.isOwner ? _expenseApi.list() : Future.value(<Expense>[]),
      _discountRequestApi.list(),
      _salesTargetApi.list(),
      _salaryApi.list(),
      _commissionApi.list(),
      _attendanceApi.list(),
      auth.isOwner ? _dashboardApi.summary() : Future.value(null),
      _settingsApi.get(),
    ]);

    return AppData(
      branches: results[0] as List<Branch>,
      employees: results[1] as List<EmployeeProfile>,
      customers: results[2] as List<Customer>,
      categories: results[3] as List<ServiceCategory>,
      services: results[4] as List<SalonService>,
      inventory: results[5] as List<InventoryItem>,
      bills: results[6] as List<Bill>,
      expenses: results[7] as List<Expense>,
      discountRequests: results[8] as List<DiscountRequest>,
      salesTargets: results[9] as List<SalesTarget>,
      salaryRecords: results[10] as List<SalaryRecord>,
      commissions: results[11] as List<CommissionRecord>,
      attendance: results[12] as List<AttendanceRecord>,
      dashboard: results[13] as DashboardSummary?,
      settings: results[14] as SalonSettings?,
    );
  }

  Future<void> refresh() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;
    state = const AsyncLoading<AppData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _loadAll(auth));
  }

  // --- Branches ---

  Future<void> addBranch({required String name, String? address, String? phone}) async {
    final created = await _branchApi.create(name: name, address: address, phone: phone);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(branches: [...current.branches, created]));
    }
  }

  Future<void> updateBranch(String id, {String? name, String? address, String? phone, String? managerId, bool? active}) async {
    final updated = await _branchApi.update(id, name: name, address: address, phone: phone, managerId: managerId, active: active);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(
        branches: current.branches.map((b) => b.id == id ? updated : b).toList(),
      ));
    }
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
    await _employeeApi.create(
      name: name,
      phone: phone,
      roleTitle: roleTitle,
      baseSalary: baseSalary,
      serviceCommissionPct: serviceCommissionPct,
      productCommissionPct: productCommissionPct,
      email: email,
      password: password,
      branchId: branchId,
    );
    await refresh();
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> changes) async {
    await _employeeApi.update(id, changes);
    await refresh();
  }

  Future<void> resetEmployeePassword(String id, String newPassword) async {
    await _employeeApi.resetPassword(id, newPassword);
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
    final created = await _customerApi.create(
      name: name,
      phone: phone,
      email: email,
      gender: gender,
      isVip: isVip,
      branchId: branchId,
    );
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(customers: [created, ...current.customers]));
    }
  }

  // --- Catalog ---

  Future<void> addServiceCategory(String name) async {
    final created = await _catalogApi.createCategory(name);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(categories: [...current.categories, created]));
    }
  }

  Future<void> addService({required String name, required double price, required String categoryId}) async {
    final created = await _catalogApi.createService(name: name, price: price, categoryId: categoryId);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(services: [...current.services, created]));
    }
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
    final created = await _catalogApi.createInventoryItem(
      sku: sku,
      name: name,
      category: category,
      price: price,
      costPrice: costPrice,
      stockCount: stockCount,
      minAlertThreshold: minAlertThreshold,
    );
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(inventory: [...current.inventory, created]));
    }
  }

  Future<void> updateInventoryStock(String id, int newStock) async {
    final updated = await _catalogApi.updateInventoryItem(id, {'stockCount': newStock});
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(
        inventory: current.inventory.map((i) => i.id == id ? updated : i).toList(),
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
    final bill = await _billApi.create(
      customerId: customerId,
      branchId: branchId,
      paymentMethod: paymentMethod,
      discountAmount: discountAmount,
      items: items,
    );
    // A bill touches sales, stock, commissions, and targets all at once -
    // simplest to just refetch everything rather than hand-patch five
    // different lists client-side.
    await refresh();
    return bill;
  }

  // --- Expenses ---

  Future<void> addExpense({required String title, required double amount, required String category, required String date, String? notes}) async {
    final created = await _expenseApi.create(title: title, amount: amount, category: category, date: date, notes: notes);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(expenses: [created, ...current.expenses]));
    }
  }

  // --- Discount requests ---

  Future<void> requestDiscount({String? billId, required double requestedDiscount, double? overridePrice, required String reason}) async {
    final created = await _discountRequestApi.create(
      billId: billId,
      requestedDiscount: requestedDiscount,
      overridePrice: overridePrice,
      reason: reason,
    );
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(discountRequests: [created, ...current.discountRequests]));
    }
  }

  Future<void> approveDiscountRequest(String id) async {
    await _discountRequestApi.approve(id);
    await refresh();
  }

  Future<void> rejectDiscountRequest(String id) async {
    await _discountRequestApi.reject(id);
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
    final created = await _salesTargetApi.create(
      employeeId: employeeId,
      type: type,
      targetValue: targetValue,
      startDate: startDate,
      endDate: endDate,
    );
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(salesTargets: [created, ...current.salesTargets]));
    }
  }

  // --- Salary ---

  Future<void> generateSalary({required int month, required int year, String? employeeId}) async {
    await _salaryApi.generate(month: month, year: year, employeeId: employeeId);
    await refresh();
  }

  Future<void> markSalaryPaid(String id) async {
    await _salaryApi.markPaid(id);
    await refresh();
  }

  // --- Commissions ---

  Future<void> markCommissionPaid(String id) async {
    await _commissionApi.markPaid(id);
    await refresh();
  }

  // --- Attendance ---

  Future<void> clockIn({double? lat, double? lng}) async {
    await _attendanceApi.clockIn(lat: lat, lng: lng);
    await refresh();
  }

  Future<void> clockOut({double? lat, double? lng}) async {
    await _attendanceApi.clockOut(lat: lat, lng: lng);
    await refresh();
  }

  Future<void> markAttendance({required String employeeId, required String date, required String status, String? notes}) async {
    await _attendanceApi.mark(employeeId: employeeId, date: date, status: status, notes: notes);
    await refresh();
  }

  // --- Settings ---

  Future<void> updateSettings(Map<String, dynamic> changes) async {
    final updated = await _settingsApi.update(changes);
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(settings: updated));
    }
  }
}

final appDataProvider = AsyncNotifierProvider<AppDataNotifier, AppData>(AppDataNotifier.new);
