import '../core/api_client.dart';
import 'models.dart';

List<Map<String, dynamic>> _list(dynamic data) =>
    (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

class BranchApi {
  final ApiClient _c;
  BranchApi(this._c);

  Future<List<Branch>> list() async =>
      _list(await _c.get('/api/v1/branches')).map(Branch.fromJson).toList();

  Future<Branch> create({required String name, String? address, String? phone}) async {
    final data = await _c.post('/api/v1/branches', data: {
      'name': name,
      if (address != null && address.isNotEmpty) 'address': address,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return Branch.fromJson(data);
  }

  Future<Branch> update(String id, {String? name, String? address, String? phone, String? managerId, bool? active}) async {
    final data = await _c.patch('/api/v1/branches/$id', data: {
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (managerId != null) 'managerId': managerId,
      if (active != null) 'active': active,
    });
    return Branch.fromJson(data);
  }
}

class EmployeeApi {
  final ApiClient _c;
  EmployeeApi(this._c);

  Future<List<EmployeeProfile>> list({String? branchId}) async =>
      _list(await _c.get('/api/v1/employees', query: {'branchId': branchId})).map(EmployeeProfile.fromJson).toList();

  Future<EmployeeProfile> create({
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
    final data = await _c.post('/api/v1/employees', data: {
      'name': name,
      'phone': phone,
      'roleTitle': roleTitle,
      'baseSalary': baseSalary,
      'serviceCommissionPct': serviceCommissionPct,
      'productCommissionPct': productCommissionPct,
      'email': email,
      'password': password,
      'branchId': branchId,
    });
    final profile = data['profile'] as Map<String, dynamic>;
    return EmployeeProfile.fromJson({...profile, 'email': data['email']});
  }

  Future<void> update(String id, Map<String, dynamic> changes) async {
    await _c.patch('/api/v1/employees/$id', data: changes);
  }

  Future<void> resetPassword(String id, String newPassword) async {
    await _c.patch('/api/v1/employees/$id/reset-password', data: {'newPassword': newPassword});
  }
}

class CustomerApi {
  final ApiClient _c;
  CustomerApi(this._c);

  Future<List<Customer>> list({String? search, String? branchId}) async =>
      _list(await _c.get('/api/v1/customers', query: {'search': search, 'branchId': branchId}))
          .map(Customer.fromJson)
          .toList();

  Future<Customer> create({
    required String name,
    required String phone,
    String? email,
    String? gender,
    bool? isVip,
    required String branchId,
  }) async {
    final data = await _c.post('/api/v1/customers', data: {
      'name': name,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (isVip != null) 'isVip': isVip,
      'branchId': branchId,
    });
    return Customer.fromJson(data);
  }

  Future<Customer> update(String id, Map<String, dynamic> changes) async {
    final data = await _c.patch('/api/v1/customers/$id', data: changes);
    return Customer.fromJson(data);
  }
}

class CatalogApi {
  final ApiClient _c;
  CatalogApi(this._c);

  Future<List<ServiceCategory>> listCategories() async =>
      _list(await _c.get('/api/v1/service-categories')).map(ServiceCategory.fromJson).toList();

  Future<ServiceCategory> createCategory(String name) async =>
      ServiceCategory.fromJson(await _c.post('/api/v1/service-categories', data: {'name': name}));

  Future<List<SalonService>> listServices() async =>
      _list(await _c.get('/api/v1/services')).map(SalonService.fromJson).toList();

  Future<SalonService> createService({required String name, required double price, required String categoryId}) async {
    final data = await _c.post('/api/v1/services', data: {'name': name, 'price': price, 'categoryId': categoryId});
    return SalonService.fromJson(data);
  }

  Future<SalonService> updateService(String id, Map<String, dynamic> changes) async =>
      SalonService.fromJson(await _c.patch('/api/v1/services/$id', data: changes));

  Future<List<InventoryItem>> listInventory() async =>
      _list(await _c.get('/api/v1/inventory')).map(InventoryItem.fromJson).toList();

  Future<InventoryItem> createInventoryItem({
    required String sku,
    required String name,
    required String category,
    required double price,
    required double costPrice,
    int? stockCount,
    int? minAlertThreshold,
  }) async {
    final data = await _c.post('/api/v1/inventory', data: {
      'sku': sku,
      'name': name,
      'category': category,
      'price': price,
      'costPrice': costPrice,
      if (stockCount != null) 'stockCount': stockCount,
      if (minAlertThreshold != null) 'minAlertThreshold': minAlertThreshold,
    });
    return InventoryItem.fromJson(data);
  }

  Future<InventoryItem> updateInventoryItem(String id, Map<String, dynamic> changes) async =>
      InventoryItem.fromJson(await _c.patch('/api/v1/inventory/$id', data: changes));
}

class BillItemInput {
  final String type; // SERVICE | PRODUCT
  final String? serviceId;
  final String? inventoryItemId;
  final String employeeId;
  final int? quantity;
  final double? unitPrice;
  final String? priceOverrideReason;
  final double? discountAmount;

  BillItemInput({
    required this.type,
    this.serviceId,
    this.inventoryItemId,
    required this.employeeId,
    this.quantity,
    this.unitPrice,
    this.priceOverrideReason,
    this.discountAmount,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        if (serviceId != null) 'serviceId': serviceId,
        if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
        'employeeId': employeeId,
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unitPrice': unitPrice,
        if (priceOverrideReason != null) 'priceOverrideReason': priceOverrideReason,
        if (discountAmount != null) 'discountAmount': discountAmount,
      };
}

class BillApi {
  final ApiClient _c;
  BillApi(this._c);

  Future<List<Bill>> list({String? from, String? to, String? branchId}) async =>
      _list(await _c.get('/api/v1/bills', query: {'from': from, 'to': to, 'branchId': branchId}))
          .map(Bill.fromJson)
          .toList();

  Future<Bill> getById(String id) async => Bill.fromJson(await _c.get('/api/v1/bills/$id'));

  Future<Bill> create({
    required String customerId,
    required String branchId,
    required String paymentMethod,
    double? discountAmount,
    required List<BillItemInput> items,
  }) async {
    final data = await _c.post('/api/v1/bills', data: {
      'customerId': customerId,
      'branchId': branchId,
      'paymentMethod': paymentMethod,
      if (discountAmount != null) 'discountAmount': discountAmount,
      'items': items.map((i) => i.toJson()).toList(),
    });
    return Bill.fromJson(data);
  }
}

class ExpenseApi {
  final ApiClient _c;
  ExpenseApi(this._c);

  Future<List<Expense>> list({String? from, String? to}) async =>
      _list(await _c.get('/api/v1/expenses', query: {'from': from, 'to': to})).map(Expense.fromJson).toList();

  Future<Expense> create({required String title, required double amount, required String category, required String date, String? notes}) async {
    final data = await _c.post('/api/v1/expenses', data: {
      'title': title,
      'amount': amount,
      'category': category,
      'date': date,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return Expense.fromJson(data);
  }
}

class DiscountRequestApi {
  final ApiClient _c;
  DiscountRequestApi(this._c);

  Future<List<DiscountRequest>> list({String? status}) async =>
      _list(await _c.get('/api/v1/discount-requests', query: {'status': status})).map(DiscountRequest.fromJson).toList();

  Future<DiscountRequest> create({String? billId, required double requestedDiscount, double? overridePrice, required String reason}) async {
    final data = await _c.post('/api/v1/discount-requests', data: {
      if (billId != null) 'billId': billId,
      'requestedDiscount': requestedDiscount,
      if (overridePrice != null) 'overridePrice': overridePrice,
      'reason': reason,
    });
    return DiscountRequest.fromJson(data);
  }

  Future<void> approve(String id) async => _c.patch('/api/v1/discount-requests/$id/approve');
  Future<void> reject(String id) async => _c.patch('/api/v1/discount-requests/$id/reject');
}

class SalesTargetApi {
  final ApiClient _c;
  SalesTargetApi(this._c);

  Future<List<SalesTarget>> list({String? employeeId}) async =>
      _list(await _c.get('/api/v1/sales-targets', query: {'employeeId': employeeId})).map(SalesTarget.fromJson).toList();

  Future<SalesTarget> create({
    required String employeeId,
    required String type,
    required double targetValue,
    required String startDate,
    required String endDate,
  }) async {
    final data = await _c.post('/api/v1/sales-targets', data: {
      'employeeId': employeeId,
      'type': type,
      'targetValue': targetValue,
      'startDate': startDate,
      'endDate': endDate,
    });
    return SalesTarget.fromJson(data);
  }
}

class SalaryApi {
  final ApiClient _c;
  SalaryApi(this._c);

  Future<List<SalaryRecord>> list({int? month, int? year, String? employeeId}) async =>
      _list(await _c.get('/api/v1/salary', query: {'month': month, 'year': year, 'employeeId': employeeId}))
          .map(SalaryRecord.fromJson)
          .toList();

  Future<void> generate({required int month, required int year, String? employeeId}) async {
    await _c.post('/api/v1/salary/generate', data: {
      'month': month,
      'year': year,
      if (employeeId != null) 'employeeId': employeeId,
    });
  }

  Future<void> markPaid(String id) async => _c.patch('/api/v1/salary/$id/pay');
}

class CommissionApi {
  final ApiClient _c;
  CommissionApi(this._c);

  Future<List<CommissionRecord>> list({String? employeeId, String? status}) async =>
      _list(await _c.get('/api/v1/commissions', query: {'employeeId': employeeId, 'status': status}))
          .map(CommissionRecord.fromJson)
          .toList();

  Future<void> markPaid(String id) async => _c.patch('/api/v1/commissions/$id/pay');
}

class AttendanceApi {
  final ApiClient _c;
  AttendanceApi(this._c);

  Future<List<AttendanceRecord>> list({String? employeeId, String? from, String? to}) async =>
      _list(await _c.get('/api/v1/attendance', query: {'employeeId': employeeId, 'from': from, 'to': to}))
          .map(AttendanceRecord.fromJson)
          .toList();

  Future<void> clockIn({double? lat, double? lng}) async =>
      _c.post('/api/v1/attendance/clock-in', data: {if (lat != null) 'lat': lat, if (lng != null) 'lng': lng});

  Future<void> clockOut({double? lat, double? lng}) async =>
      _c.post('/api/v1/attendance/clock-out', data: {if (lat != null) 'lat': lat, if (lng != null) 'lng': lng});

  Future<void> mark({required String employeeId, required String date, required String status, String? notes}) async {
    await _c.post('/api/v1/attendance/mark', data: {
      'employeeId': employeeId,
      'date': date,
      'status': status,
      if (notes != null) 'notes': notes,
    });
  }
}

class DashboardApi {
  final ApiClient _c;
  DashboardApi(this._c);

  Future<DashboardSummary> summary() async => DashboardSummary.fromJson(await _c.get('/api/v1/dashboard/summary'));
}

class SettingsApi {
  final ApiClient _c;
  SettingsApi(this._c);

  Future<SalonSettings> get() async => SalonSettings.fromJson(await _c.get('/api/v1/settings'));

  Future<SalonSettings> update(Map<String, dynamic> changes) async =>
      SalonSettings.fromJson(await _c.patch('/api/v1/settings', data: changes));
}
