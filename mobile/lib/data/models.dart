// Models mirroring the backend's actual JSON responses. Prisma serializes
// Decimal fields as strings (e.g. "500.00"), so every numeric field is
// parsed defensively via `_num`/`_int` rather than cast directly.

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _int(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class Branch {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool active;
  final String? managerId;
  final String? managerName;
  final int employeeCount;
  final int customerCount;
  final double monthlyRevenue;

  Branch({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.active,
    this.managerId,
    this.managerName,
    required this.employeeCount,
    required this.customerCount,
    required this.monthlyRevenue,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: json['id'],
        name: json['name'],
        address: json['address'],
        phone: json['phone'],
        active: json['active'] ?? true,
        managerId: json['managerId'],
        managerName: json['managerName'],
        employeeCount: _int(json['employeeCount']),
        customerCount: _int(json['customerCount']),
        monthlyRevenue: _num(json['monthlyRevenue']),
      );
}

class EmployeeProfile {
  final String id;
  final String userId;
  final String email;
  final String name;
  final String phone;
  final String roleTitle;
  final bool active;
  final double baseSalary;
  final double serviceCommissionPct;
  final double productCommissionPct;
  final String branchId;
  final String? branchName;

  EmployeeProfile({
    required this.id,
    required this.userId,
    required this.email,
    required this.name,
    required this.phone,
    required this.roleTitle,
    required this.active,
    required this.baseSalary,
    required this.serviceCommissionPct,
    required this.productCommissionPct,
    required this.branchId,
    this.branchName,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) => EmployeeProfile(
        id: json['id'],
        userId: json['userId'] ?? '',
        email: json['email'] ?? '',
        name: json['name'],
        phone: json['phone'],
        roleTitle: json['roleTitle'],
        active: json['active'] ?? true,
        baseSalary: _num(json['baseSalary']),
        serviceCommissionPct: _num(json['serviceCommissionPct']),
        productCommissionPct: _num(json['productCommissionPct']),
        branchId: json['branchId'] ?? '',
        branchName: json['branchName'],
      );
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? gender;
  final String? notes;
  final bool isVip;
  final String branchId;
  final DateTime? createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.gender,
    this.notes,
    required this.isVip,
    required this.branchId,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        email: json['email'],
        gender: json['gender'],
        notes: json['notes'],
        isVip: json['isVip'] ?? false,
        branchId: json['branchId'] ?? '',
        createdAt: _date(json['createdAt']),
      );
}

class ServiceCategory {
  final String id;
  final String name;

  ServiceCategory({required this.id, required this.name});

  factory ServiceCategory.fromJson(Map<String, dynamic> json) =>
      ServiceCategory(id: json['id'], name: json['name']);
}

class SalonService {
  final String id;
  final String name;
  final double price;
  final String categoryId;
  final String? categoryName;

  SalonService({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    this.categoryName,
  });

  factory SalonService.fromJson(Map<String, dynamic> json) => SalonService(
        id: json['id'],
        name: json['name'],
        price: _num(json['price']),
        categoryId: json['categoryId'] ?? '',
        categoryName: (json['category'] is Map) ? json['category']['name'] : null,
      );
}

class InventoryItem {
  final String id;
  final String sku;
  final String name;
  final String category;
  final double price;
  final double costPrice;
  final int stockCount;
  final int minAlertThreshold;

  InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.costPrice,
    required this.stockCount,
    required this.minAlertThreshold,
  });

  bool get isLowStock => stockCount <= minAlertThreshold;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'],
        sku: json['sku'],
        name: json['name'],
        category: json['category'],
        price: _num(json['price']),
        costPrice: _num(json['costPrice']),
        stockCount: _int(json['stockCount']),
        minAlertThreshold: _int(json['minAlertThreshold']),
      );
}

class BillItem {
  final String id;
  final String type; // SERVICE | PRODUCT
  final String? serviceId;
  final String? serviceName;
  final String? inventoryItemId;
  final String? productName;
  final int quantity;
  final double unitPrice;
  final double discountAmount;
  final String employeeId;
  final String? employeeName;
  final double calculatedCommission;

  BillItem({
    required this.id,
    required this.type,
    this.serviceId,
    this.serviceName,
    this.inventoryItemId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.employeeId,
    this.employeeName,
    required this.calculatedCommission,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
        id: json['id'],
        type: json['type'],
        serviceId: json['serviceId'],
        serviceName: (json['service'] is Map) ? json['service']['name'] : null,
        inventoryItemId: json['inventoryItemId'],
        productName: (json['inventoryItem'] is Map) ? json['inventoryItem']['name'] : null,
        quantity: _int(json['quantity']),
        unitPrice: _num(json['unitPrice']),
        discountAmount: _num(json['discountAmount']),
        employeeId: json['employeeId'] ?? '',
        employeeName: (json['employee'] is Map) ? json['employee']['name'] : null,
        calculatedCommission: _num(json['calculatedCommission']),
      );
}

class Bill {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String? customerName;
  final String branchId;
  final double subTotal;
  final double discountAmount;
  final double taxAmount;
  final double finalAmount;
  final String paymentMethod; // CASH | CARD | UPI
  final String status;
  final DateTime? createdAt;
  final List<BillItem> items;

  Bill({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    this.customerName,
    required this.branchId,
    required this.subTotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.finalAmount,
    required this.paymentMethod,
    required this.status,
    this.createdAt,
    required this.items,
  });

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'],
        invoiceNumber: json['invoiceNumber'],
        customerId: json['customerId'] ?? '',
        customerName: (json['customer'] is Map) ? json['customer']['name'] : null,
        branchId: json['branchId'] ?? '',
        subTotal: _num(json['subTotal']),
        discountAmount: _num(json['discountAmount']),
        taxAmount: _num(json['taxAmount']),
        finalAmount: _num(json['finalAmount']),
        paymentMethod: json['paymentMethod'],
        status: json['status'] ?? 'COMPLETED',
        createdAt: _date(json['createdAt']),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime? date;
  final String? notes;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.date,
    this.notes,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        amount: _num(json['amount']),
        category: json['category'],
        date: _date(json['date']),
        notes: json['notes'],
      );
}

class DiscountRequest {
  final String id;
  final String requestedBy;
  final String? billId;
  final double requestedDiscount;
  final double? overridePrice;
  final String reason;
  final String status; // PENDING | APPROVED | REJECTED
  final String? authorizedCode;
  final DateTime? createdAt;

  DiscountRequest({
    required this.id,
    required this.requestedBy,
    this.billId,
    required this.requestedDiscount,
    this.overridePrice,
    required this.reason,
    required this.status,
    this.authorizedCode,
    this.createdAt,
  });

  factory DiscountRequest.fromJson(Map<String, dynamic> json) => DiscountRequest(
        id: json['id'],
        requestedBy: json['requestedBy'] ?? '',
        billId: json['billId'],
        requestedDiscount: _num(json['requestedDiscount']),
        overridePrice: json['overridePrice'] == null ? null : _num(json['overridePrice']),
        reason: json['reason'] ?? '',
        status: json['status'] ?? 'PENDING',
        authorizedCode: json['authorizedCode'],
        createdAt: _date(json['createdAt']),
      );
}

class SalesTarget {
  final String id;
  final String employeeId;
  final String type; // SERVICE_VOLUME | PRODUCT_SALES_COUNT
  final double targetValue;
  final double progressValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // ACTIVE | ACHIEVED | FAILED

  SalesTarget({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.targetValue,
    required this.progressValue,
    this.startDate,
    this.endDate,
    required this.status,
  });

  double get progressFraction => targetValue == 0 ? 0 : (progressValue / targetValue).clamp(0, 1);

  factory SalesTarget.fromJson(Map<String, dynamic> json) => SalesTarget(
        id: json['id'],
        employeeId: json['employeeId'] ?? '',
        type: json['type'],
        targetValue: _num(json['targetValue']),
        progressValue: _num(json['progressValue']),
        startDate: _date(json['startDate']),
        endDate: _date(json['endDate']),
        status: json['status'] ?? 'ACTIVE',
      );
}

class SalaryRecord {
  final String id;
  final String employeeId;
  final int month;
  final int year;
  final double baseSalary;
  final double commissionEarned;
  final double deductions;
  final double totalPaid;
  final String status; // DRAFT | PAID

  SalaryRecord({
    required this.id,
    required this.employeeId,
    required this.month,
    required this.year,
    required this.baseSalary,
    required this.commissionEarned,
    required this.deductions,
    required this.totalPaid,
    required this.status,
  });

  factory SalaryRecord.fromJson(Map<String, dynamic> json) => SalaryRecord(
        id: json['id'],
        employeeId: json['employeeId'] ?? '',
        month: _int(json['month']),
        year: _int(json['year']),
        baseSalary: _num(json['baseSalary']),
        commissionEarned: _num(json['commissionEarned']),
        deductions: _num(json['deductions']),
        totalPaid: _num(json['totalPaid']),
        status: json['status'] ?? 'DRAFT',
      );
}

class CommissionRecord {
  final String id;
  final String employeeId;
  final String billItemId;
  final double amount;
  final String status; // PENDING | PAID
  final DateTime? calculatedAt;

  CommissionRecord({
    required this.id,
    required this.employeeId,
    required this.billItemId,
    required this.amount,
    required this.status,
    this.calculatedAt,
  });

  factory CommissionRecord.fromJson(Map<String, dynamic> json) => CommissionRecord(
        id: json['id'],
        employeeId: json['employeeId'] ?? '',
        billItemId: json['billItemId'] ?? '',
        amount: _num(json['amount']),
        status: json['status'] ?? 'PENDING',
        calculatedAt: _date(json['calculatedAt']),
      );
}

class AttendanceRecord {
  final String id;
  final String employeeId;
  final DateTime? date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String status; // PRESENT | LATE | ABSENT

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    this.date,
    this.clockIn,
    this.clockOut,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'],
        employeeId: json['employeeId'] ?? '',
        date: _date(json['date']),
        clockIn: _date(json['clockIn']),
        clockOut: _date(json['clockOut']),
        status: json['status'] ?? 'PRESENT',
      );
}

class DashboardSummary {
  final double todaySales;
  final double weekSales;
  final double monthSales;
  final double todayCash;
  final double todayCard;
  final double todayUpi;
  final int todayCustomersCount;
  final int todayBillCount;
  final int todayAttendanceCount;
  final int pendingDiscountRequests;
  final int lowStockItemCount;

  DashboardSummary({
    required this.todaySales,
    required this.weekSales,
    required this.monthSales,
    required this.todayCash,
    required this.todayCard,
    required this.todayUpi,
    required this.todayCustomersCount,
    required this.todayBillCount,
    required this.todayAttendanceCount,
    required this.pendingDiscountRequests,
    required this.lowStockItemCount,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final breakdown = json['todayPaymentBreakdown'] as Map<String, dynamic>? ?? {};
    return DashboardSummary(
      todaySales: _num(json['todaySales']),
      weekSales: _num(json['weekSales']),
      monthSales: _num(json['monthSales']),
      todayCash: _num(breakdown['CASH']),
      todayCard: _num(breakdown['CARD']),
      todayUpi: _num(breakdown['UPI']),
      todayCustomersCount: _int(json['todayCustomersCount']),
      todayBillCount: _int(json['todayBillCount']),
      todayAttendanceCount: _int(json['todayAttendanceCount']),
      pendingDiscountRequests: _int(json['pendingDiscountRequests']),
      lowStockItemCount: _int(json['lowStockItemCount']),
    );
  }

  factory DashboardSummary.empty() => DashboardSummary(
        todaySales: 0,
        weekSales: 0,
        monthSales: 0,
        todayCash: 0,
        todayCard: 0,
        todayUpi: 0,
        todayCustomersCount: 0,
        todayBillCount: 0,
        todayAttendanceCount: 0,
        pendingDiscountRequests: 0,
        lowStockItemCount: 0,
      );
}

class SalonSettings {
  final String salonName;
  final String? phone;
  final String? address;
  final double gstRate;
  final double lateAttendancePenalty;

  SalonSettings({
    required this.salonName,
    this.phone,
    this.address,
    required this.gstRate,
    required this.lateAttendancePenalty,
  });

  factory SalonSettings.fromJson(Map<String, dynamic> json) => SalonSettings(
        salonName: json['salonName'] ?? 'Salon',
        phone: json['phone'],
        address: json['address'],
        gstRate: _num(json['gstRate']),
        lateAttendancePenalty: _num(json['lateAttendancePenalty']),
      );
}
