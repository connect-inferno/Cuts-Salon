import 'package:cloud_firestore/cloud_firestore.dart';

// Firestore-native equivalents of mobile/lib/data/models.dart. No salonId
// anywhere - each salon is its own Firebase project, so the project itself
// is the tenant boundary (see salon_directory.dart). Every id comes from
// doc.id, never duplicated inside the document body.

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

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

class FSBranch {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool active;
  final String? managerId;
  final String? managerName;

  FSBranch({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.active,
    this.managerId,
    this.managerName,
  });

  factory FSBranch.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSBranch(
      id: doc.id,
      name: d['name'] ?? '',
      address: d['address'],
      phone: d['phone'],
      active: d['active'] ?? true,
      managerId: d['managerId'],
      managerName: d['managerName'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'address': address,
        'phone': phone,
        'active': active,
        'managerId': managerId,
        'managerName': managerName,
      };
}

class FSEmployee {
  final String id;
  final String userId; // Firebase Auth uid
  final String email;
  final String name;
  final String phone;
  final String roleTitle;
  final String role; // 'OWNER' | 'EMPLOYEE'
  final bool active;
  final double baseSalary;
  final double serviceCommissionPct;
  final double productCommissionPct;
  final String branchId;
  final String? branchName;

  FSEmployee({
    required this.id,
    required this.userId,
    required this.email,
    required this.name,
    required this.phone,
    required this.roleTitle,
    required this.role,
    required this.active,
    required this.baseSalary,
    required this.serviceCommissionPct,
    required this.productCommissionPct,
    required this.branchId,
    this.branchName,
  });

  factory FSEmployee.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSEmployee(
      id: doc.id,
      userId: d['userId'] ?? '',
      email: d['email'] ?? '',
      name: d['name'] ?? '',
      phone: d['phone'] ?? '',
      roleTitle: d['roleTitle'] ?? '',
      role: d['role'] ?? 'EMPLOYEE',
      active: d['active'] ?? true,
      baseSalary: _num(d['baseSalary']),
      serviceCommissionPct: _num(d['serviceCommissionPct']),
      productCommissionPct: _num(d['productCommissionPct']),
      branchId: d['branchId'] ?? '',
      branchName: d['branchName'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'email': email,
        'name': name,
        'phone': phone,
        'roleTitle': roleTitle,
        'role': role,
        'active': active,
        'baseSalary': baseSalary,
        'serviceCommissionPct': serviceCommissionPct,
        'productCommissionPct': productCommissionPct,
        'branchId': branchId,
        'branchName': branchName,
      };
}

class FSCustomer {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? gender;
  final String? notes;
  final bool isVip;
  final String branchId;
  final DateTime? createdAt;
  // Denormalized onto the customer doc (incremented atomically inside
  // createBill's transaction) instead of computed by re-reading a salon's
  // entire bill history on every load - see the comment on listBills() for
  // why that doesn't scale.
  final int visitCount;
  final double totalSpent;
  final DateTime? lastVisitAt;

  FSCustomer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.gender,
    this.notes,
    required this.isVip,
    required this.branchId,
    this.createdAt,
    this.visitCount = 0,
    this.totalSpent = 0,
    this.lastVisitAt,
  });

  factory FSCustomer.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSCustomer(
      id: doc.id,
      name: d['name'] ?? '',
      phone: d['phone'] ?? '',
      email: d['email'],
      gender: d['gender'],
      notes: d['notes'],
      isVip: d['isVip'] ?? false,
      branchId: d['branchId'] ?? '',
      createdAt: _ts(d['createdAt']),
      visitCount: _int(d['visitCount']),
      totalSpent: _num(d['totalSpent']),
      lastVisitAt: _ts(d['lastVisitAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool isCreate = false}) => {
        'name': name,
        'phone': phone,
        'email': email,
        'gender': gender,
        'notes': notes,
        'isVip': isVip,
        'branchId': branchId,
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
        if (isCreate) 'visitCount': 0,
        if (isCreate) 'totalSpent': 0,
      };
}

class FSServiceCategory {
  final String id;
  final String name;

  FSServiceCategory({required this.id, required this.name});

  factory FSServiceCategory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FSServiceCategory(id: doc.id, name: doc.data()!['name'] ?? '');

  Map<String, dynamic> toFirestore() => {'name': name};
}

class FSService {
  final String id;
  final String name;
  final double price;
  final String categoryId;
  final String? categoryName;

  FSService({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    this.categoryName,
  });

  factory FSService.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSService(
      id: doc.id,
      name: d['name'] ?? '',
      price: _num(d['price']),
      categoryId: d['categoryId'] ?? '',
      categoryName: d['categoryName'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'price': price,
        'categoryId': categoryId,
        'categoryName': categoryName,
      };
}

class FSInventoryItem {
  final String id;
  final String sku;
  final String name;
  final String category;
  final double price;
  final double costPrice;
  final int stockCount;
  final int minAlertThreshold;

  FSInventoryItem({
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

  factory FSInventoryItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSInventoryItem(
      id: doc.id,
      sku: d['sku'] ?? '',
      name: d['name'] ?? '',
      category: d['category'] ?? '',
      price: _num(d['price']),
      costPrice: _num(d['costPrice']),
      stockCount: _int(d['stockCount']),
      minAlertThreshold: _int(d['minAlertThreshold']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sku': sku,
        'name': name,
        'category': category,
        'price': price,
        'costPrice': costPrice,
        'stockCount': stockCount,
        'minAlertThreshold': minAlertThreshold,
      };
}

class FSBillItem {
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

  FSBillItem({
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

  factory FSBillItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSBillItem(
      id: doc.id,
      type: d['type'] ?? 'SERVICE',
      serviceId: d['serviceId'],
      serviceName: d['serviceName'],
      inventoryItemId: d['inventoryItemId'],
      productName: d['productName'],
      quantity: _int(d['quantity']),
      unitPrice: _num(d['unitPrice']),
      discountAmount: _num(d['discountAmount']),
      employeeId: d['employeeId'] ?? '',
      employeeName: d['employeeName'],
      calculatedCommission: _num(d['calculatedCommission']),
    );
  }

  // Names are denormalized here at write time - there's no server-side
  // `include` in Firestore, so whatever's passed in is what every future
  // reader sees, even if the service/employee is later renamed.
  Map<String, dynamic> toFirestore() => {
        'type': type,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'inventoryItemId': inventoryItemId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountAmount': discountAmount,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'calculatedCommission': calculatedCommission,
      };
}

class FSBill {
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
  final String createdBy;
  final DateTime? createdAt;
  final List<FSBillItem> items; // populated separately from the subcollection

  FSBill({
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
    required this.createdBy,
    this.createdAt,
    this.items = const [],
  });

  factory FSBill.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, {List<FSBillItem> items = const []}) {
    final d = doc.data()!;
    return FSBill(
      id: doc.id,
      invoiceNumber: d['invoiceNumber'] ?? '',
      customerId: d['customerId'] ?? '',
      customerName: d['customerName'],
      branchId: d['branchId'] ?? '',
      subTotal: _num(d['subTotal']),
      discountAmount: _num(d['discountAmount']),
      taxAmount: _num(d['taxAmount']),
      finalAmount: _num(d['finalAmount']),
      paymentMethod: d['paymentMethod'] ?? 'CASH',
      createdBy: d['createdBy'] ?? '',
      createdAt: _ts(d['createdAt']),
      items: items,
    );
  }

  Map<String, dynamic> toFirestore({bool isCreate = false}) => {
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName,
        'branchId': branchId,
        'subTotal': subTotal,
        'discountAmount': discountAmount,
        'taxAmount': taxAmount,
        'finalAmount': finalAmount,
        'paymentMethod': paymentMethod,
        'createdBy': createdBy,
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      };
}

class FSAttendanceRecord {
  final String id; // "{employeeId}_{yyyy-MM-dd}"
  final String employeeId;
  final DateTime? date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String status; // PRESENT | LATE | ABSENT

  FSAttendanceRecord({
    required this.id,
    required this.employeeId,
    this.date,
    this.clockIn,
    this.clockOut,
    required this.status,
  });

  factory FSAttendanceRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSAttendanceRecord(
      id: doc.id,
      employeeId: d['employeeId'] ?? '',
      date: _ts(d['date']),
      clockIn: _ts(d['clockIn']),
      clockOut: _ts(d['clockOut']),
      status: d['status'] ?? 'PRESENT',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'employeeId': employeeId,
        'date': date == null ? null : Timestamp.fromDate(date!),
        'clockIn': clockIn == null ? null : Timestamp.fromDate(clockIn!),
        'clockOut': clockOut == null ? null : Timestamp.fromDate(clockOut!),
        'status': status,
      };
}

class FSSalaryRecord {
  final String id;
  final String employeeId;
  final int month;
  final int year;
  final double baseSalary;
  final double commissionEarned;
  final double deductions;
  final double totalPaid;
  final String status; // DRAFT | PAID

  FSSalaryRecord({
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

  factory FSSalaryRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSSalaryRecord(
      id: doc.id,
      employeeId: d['employeeId'] ?? '',
      month: _int(d['month']),
      year: _int(d['year']),
      baseSalary: _num(d['baseSalary']),
      commissionEarned: _num(d['commissionEarned']),
      deductions: _num(d['deductions']),
      totalPaid: _num(d['totalPaid']),
      status: d['status'] ?? 'DRAFT',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'employeeId': employeeId,
        'month': month,
        'year': year,
        'baseSalary': baseSalary,
        'commissionEarned': commissionEarned,
        'deductions': deductions,
        'totalPaid': totalPaid,
        'status': status,
      };
}

class FSCommissionRecord {
  final String id;
  final String employeeId;
  final String billId;
  final String billItemId;
  final double amount;
  final String status; // PENDING | PAID
  final DateTime? createdAt;

  FSCommissionRecord({
    required this.id,
    required this.employeeId,
    required this.billId,
    required this.billItemId,
    required this.amount,
    required this.status,
    this.createdAt,
  });

  factory FSCommissionRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSCommissionRecord(
      id: doc.id,
      employeeId: d['employeeId'] ?? '',
      billId: d['billId'] ?? '',
      billItemId: d['billItemId'] ?? '',
      amount: _num(d['amount']),
      status: d['status'] ?? 'PENDING',
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool isCreate = false}) => {
        'employeeId': employeeId,
        'billId': billId,
        'billItemId': billItemId,
        'amount': amount,
        'status': status,
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      };
}

class FSSalesTarget {
  final String id;
  final String employeeId;
  final String type; // SERVICE_VOLUME | PRODUCT_SALES_COUNT
  final double targetValue;
  final double progressValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // ACTIVE | ACHIEVED | FAILED

  FSSalesTarget({
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

  factory FSSalesTarget.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSSalesTarget(
      id: doc.id,
      employeeId: d['employeeId'] ?? '',
      type: d['type'] ?? 'SERVICE_VOLUME',
      targetValue: _num(d['targetValue']),
      progressValue: _num(d['progressValue']),
      startDate: _ts(d['startDate']),
      endDate: _ts(d['endDate']),
      status: d['status'] ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'employeeId': employeeId,
        'type': type,
        'targetValue': targetValue,
        'progressValue': progressValue,
        'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
        'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
        'status': status,
      };
}

class FSExpense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime? date;
  final String? notes;

  FSExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.date,
    this.notes,
  });

  factory FSExpense.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSExpense(
      id: doc.id,
      title: d['title'] ?? '',
      amount: _num(d['amount']),
      category: d['category'] ?? 'MISC',
      date: _ts(d['date']),
      notes: d['notes'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'amount': amount,
        'category': category,
        'date': date == null ? null : Timestamp.fromDate(date!),
        'notes': notes,
      };
}

class FSDiscountRequest {
  final String id;
  final String requestedBy; // employee's Firebase Auth uid
  final String? billId;
  final double requestedDiscount;
  final double? overridePrice;
  final String reason;
  final String status; // PENDING | APPROVED | REJECTED
  final String? authorizedCode;
  final DateTime? createdAt;

  FSDiscountRequest({
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

  factory FSDiscountRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FSDiscountRequest(
      id: doc.id,
      requestedBy: d['requestedBy'] ?? '',
      billId: d['billId'],
      requestedDiscount: _num(d['requestedDiscount']),
      overridePrice: d['overridePrice'] == null ? null : _num(d['overridePrice']),
      reason: d['reason'] ?? '',
      status: d['status'] ?? 'PENDING',
      authorizedCode: d['authorizedCode'],
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool isCreate = false}) => {
        'requestedBy': requestedBy,
        'billId': billId,
        'requestedDiscount': requestedDiscount,
        'overridePrice': overridePrice,
        'reason': reason,
        'status': status,
        'authorizedCode': authorizedCode,
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      };
}

class FSSettings {
  final String salonName;
  final String? phone;
  final String? address;
  final double gstRate;
  final double lateAttendancePenalty;

  FSSettings({
    required this.salonName,
    this.phone,
    this.address,
    required this.gstRate,
    required this.lateAttendancePenalty,
  });

  factory FSSettings.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return FSSettings(
      salonName: d['salonName'] ?? 'Salon',
      phone: d['phone'],
      address: d['address'],
      gstRate: _num(d['gstRate'] ?? 18),
      lateAttendancePenalty: _num(d['lateAttendancePenalty']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'salonName': salonName,
        'phone': phone,
        'address': address,
        'gstRate': gstRate,
        'lateAttendancePenalty': lateAttendancePenalty,
      };
}
