import 'models.dart';

// Split out of app_data_provider.dart so both the REST provider and
// firebase/firestore_app_data.dart's Firestore assembler can build one
// without importing each other.
// One employee's outstanding commission, split by line type. Both the
// employee's own Earnings screen and the owner's Payroll Estimate card read
// this, so the two can never disagree about the same person's pay - they
// previously computed it two different ways (pending-only vs month-to-date)
// under the same "Service Commission" label and showed different numbers.
class PendingCommissionSplit {
  final double service;
  final double product;
  final double serviceBillings;
  final double productBillings;
  // Pending commission whose bill item isn't in the loaded (capped) bills
  // list, so it can't be attributed to a type. Counted in `total` regardless,
  // so the parts always add up to the headline figure.
  final double unattributed;
  final double total;

  const PendingCommissionSplit({
    required this.service,
    required this.product,
    required this.serviceBillings,
    required this.productBillings,
    required this.unattributed,
    required this.total,
  });
}

class AppData {
  final List<Branch> branches;
  final List<EmployeeProfile> employees;
  // Active clients only. Archived ones are kept in a separate list so no
  // picker, search or billing flow can surface them by accident - anything
  // that wants a client to bill reads `customers` and gets only live ones.
  final List<Customer> customers;
  final List<Customer> archivedCustomers;
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
    this.archivedCustomers = const [],
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

  PendingCommissionSplit pendingCommissionFor(String employeeId) {
    final pending = commissions.where((c) => c.employeeId == employeeId && c.status == 'PENDING').toList();
    final total = pending.fold<double>(0, (sum, c) => sum + c.amount);
    final pendingItemIds = pending.map((c) => c.billItemId).toSet();

    double service = 0;
    double product = 0;
    double serviceBillings = 0;
    double productBillings = 0;
    for (final bill in bills) {
      for (final item in bill.items) {
        if (item.employeeId != employeeId || !pendingItemIds.contains(item.id)) continue;
        final gross = (item.unitPrice * item.quantity) - item.discountAmount;
        if (item.type == 'SERVICE') {
          service += item.calculatedCommission;
          serviceBillings += gross;
        } else {
          product += item.calculatedCommission;
          productBillings += gross;
        }
      }
    }

    return PendingCommissionSplit(
      service: service,
      product: product,
      serviceBillings: serviceBillings,
      productBillings: productBillings,
      unattributed: total - (service + product),
      total: total,
    );
  }

  Branch? branchById(String id) {
    final match = branches.where((b) => b.id == id);
    return match.isEmpty ? null : match.first;
  }

  AppData copyWith({
    List<Branch>? branches,
    List<EmployeeProfile>? employees,
    List<Customer>? customers,
    List<Customer>? archivedCustomers,
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
      archivedCustomers: archivedCustomers ?? this.archivedCustomers,
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
