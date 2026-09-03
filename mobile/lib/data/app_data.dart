import 'models.dart';

// Split out of app_data_provider.dart so both the REST provider and
// firebase/firestore_app_data.dart's Firestore assembler can build one
// without importing each other.
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
