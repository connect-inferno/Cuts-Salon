import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firestore_models.dart';

double _round2(num n) => (n * 100).round() / 100;
final _random = Random.secure();

// One instance per logged-in session, built from that salon's own named
// FirebaseApp (see salon_auth.dart) - never a global/default Firestore
// instance, since which project is "the database" depends on which salon
// signed in.
//
// Note on the salary redaction the REST backend does (employee.service.ts
// hides a coworker's baseSalary/commission from non-owners): Firestore
// Security Rules grant or deny a whole document, they can't strip individual
// fields on read the way a REST controller can reshape its response. Doing
// that here would mean either a Cloud Function acting as a read proxy (real
// backend code, defeating a lot of the point of going server-less) or
// duplicating pay fields into a second, owner-only-readable document per
// employee. Neither is built yet - listEmployees() below returns the whole
// document, so *the caller* (whatever UI eventually renders this list) must
// only display baseSalary/serviceCommissionPct/productCommissionPct when
// viewing your own profile or when the viewer is the owner, exactly like the
// old employee.service.ts canSeePay check, just enforced client-side instead
// of server-side. That's a real, deliberate gap - flagging it so it isn't
// mistaken for equivalent security to the REST backend.
class SalonFirestore {
  final FirebaseFirestore db;

  SalonFirestore(FirebaseApp app) : db = FirebaseFirestore.instanceFor(app: app);

  // --- Settings (single fixed-id document) ---

  Future<FSSettings> getSettings() async {
    final doc = await db.collection('settings').doc('main').get();
    return FSSettings.fromFirestore(doc);
  }

  Future<void> updateSettings(Map<String, dynamic> changes) =>
      db.collection('settings').doc('main').set(changes, SetOptions(merge: true));

  // --- Branches ---

  Future<List<FSBranch>> listBranches() async {
    final snap = await db.collection('branches').get();
    return snap.docs.map(FSBranch.fromFirestore).toList();
  }

  Future<FSBranch> createBranch({required String name, String? address, String? phone}) async {
    final ref = await db.collection('branches').add(
          FSBranch(id: '', name: name, address: address, phone: phone, active: true).toFirestore(),
        );
    return FSBranch.fromFirestore(await ref.get());
  }

  Future<void> updateBranch(String id, Map<String, dynamic> changes) => db.collection('branches').doc(id).update(changes);

  Future<FSBranch?> getBranch(String id) async {
    final doc = await db.collection('branches').doc(id).get();
    return doc.exists ? FSBranch.fromFirestore(doc) : null;
  }

  // Mirrors branch.service.ts's per-salon name-uniqueness check.
  Future<bool> isBranchNameTaken(String name) async {
    final snap = await db.collection('branches').where('name', isEqualTo: name).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  // --- Employees ---
  // Doc ID is always the Firebase Auth uid (see firestore.rules) - an
  // employee's *auth* account has to be created first (Admin SDK only, so
  // via the Firebase Console or a future Cloud Function), then their
  // profile document is written here against that same uid.

  Future<List<FSEmployee>> listEmployees() async {
    final snap = await db.collection('employees').get();
    return snap.docs.map(FSEmployee.fromFirestore).toList();
  }

  Future<FSEmployee?> getEmployee(String uid) async {
    final doc = await db.collection('employees').doc(uid).get();
    if (!doc.exists) return null;
    return FSEmployee.fromFirestore(doc);
  }

  Future<void> writeEmployeeProfile(String uid, FSEmployee profile) => db.collection('employees').doc(uid).set(profile.toFirestore());

  Future<void> updateEmployee(String uid, Map<String, dynamic> changes) => db.collection('employees').doc(uid).update(changes);

  // Mirrors employee.service.ts's per-salon phone-uniqueness check.
  Future<bool> isPhoneTaken(String phone) async {
    final snap = await db.collection('employees').where('phone', isEqualTo: phone).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  // --- Customers ---

  Future<List<FSCustomer>> listCustomers() async {
    final snap = await db.collection('customers').orderBy('createdAt', descending: true).get();
    return snap.docs.map(FSCustomer.fromFirestore).toList();
  }

  Future<FSCustomer> createCustomer(FSCustomer customer) async {
    final ref = await db.collection('customers').add(customer.toFirestore(isCreate: true));
    return FSCustomer.fromFirestore(await ref.get());
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> changes) => db.collection('customers').doc(id).update(changes);

  // Mirrors customer.service.ts's per-salon phone-uniqueness check.
  Future<bool> isCustomerPhoneTaken(String phone) async {
    final snap = await db.collection('customers').where('phone', isEqualTo: phone).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  // --- Catalog ---

  Future<List<FSServiceCategory>> listServiceCategories() async {
    final snap = await db.collection('serviceCategories').get();
    return snap.docs.map(FSServiceCategory.fromFirestore).toList();
  }

  Future<FSServiceCategory> createServiceCategory(String name) async {
    final ref = await db.collection('serviceCategories').add({'name': name});
    return FSServiceCategory.fromFirestore(await ref.get());
  }

  // Mirrors serviceCategory.service.ts's per-salon name-uniqueness check.
  Future<bool> isServiceCategoryNameTaken(String name) async {
    final snap = await db.collection('serviceCategories').where('name', isEqualTo: name).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  Future<List<FSService>> listServices() async {
    final snap = await db.collection('services').get();
    return snap.docs.map(FSService.fromFirestore).toList();
  }

  Future<FSService> createService(FSService service) async {
    final ref = await db.collection('services').add(service.toFirestore());
    return FSService.fromFirestore(await ref.get());
  }

  // Mirrors service.service.ts's per-salon name-uniqueness check.
  Future<bool> isServiceNameTaken(String name) async {
    final snap = await db.collection('services').where('name', isEqualTo: name).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  Future<List<FSInventoryItem>> listInventory() async {
    final snap = await db.collection('inventoryItems').get();
    return snap.docs.map(FSInventoryItem.fromFirestore).toList();
  }

  Future<FSInventoryItem> createInventoryItem(FSInventoryItem item) async {
    final ref = await db.collection('inventoryItems').add(item.toFirestore());
    return FSInventoryItem.fromFirestore(await ref.get());
  }

  Future<void> updateInventoryItem(String id, Map<String, dynamic> changes) => db.collection('inventoryItems').doc(id).update(changes);

  // Mirrors inventory.service.ts's per-salon SKU-uniqueness check.
  Future<bool> isSkuTaken(String sku) async {
    final snap = await db.collection('inventoryItems').where('sku', isEqualTo: sku).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  // --- Bills ---
  // The one operation that genuinely needs a transaction: atomically write
  // the bill + its items, a commission record per item, bump any matching
  // active sales target, and decrement stock for product items - mirroring
  // backend/src/services/bill.service.ts's Prisma $transaction.
  //
  // Firestore client transactions only support get() on a known
  // DocumentReference, never a where() query, and every get() must happen
  // before any set()/update() in the callback. Sales targets are looked up
  // by query, so that lookup runs *before* runTransaction; each matching
  // target document is then re-read via tx.get() inside the transaction so
  // its update is still transactionally consistent at commit time.
  Future<FSBill> createBill({
    required String customerId,
    required String customerName,
    required String branchId,
    required String paymentMethod,
    required String createdBy,
    required double gstRate,
    required List<BillItemDraft> items,
    double billDiscountAmount = 0,
  }) async {
    if (items.isEmpty) throw Exception('A bill must have at least one item');
    final billRef = db.collection('bills').doc();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final targetDocsByEmployee = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final item in items) {
      if (targetDocsByEmployee.containsKey(item.employeeId)) continue;
      final targetType = item.type == 'SERVICE' ? 'SERVICE_VOLUME' : 'PRODUCT_SALES_COUNT';
      final snap = await db
          .collection('salesTargets')
          .where('employeeId', isEqualTo: item.employeeId)
          .where('type', isEqualTo: targetType)
          .where('status', isEqualTo: 'ACTIVE')
          .get();
      targetDocsByEmployee[item.employeeId] = snap.docs;
    }

    return db.runTransaction<FSBill>((tx) async {
      // ---- READS (must all happen before any write below) ----
      final freshTargets = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final docs in targetDocsByEmployee.values) {
        for (final d in docs) {
          freshTargets[d.reference.path] = await tx.get(d.reference);
        }
      }

      // ---- COMPUTE ----
      double subTotal = 0;
      double itemDiscountTotal = 0;
      for (final item in items) {
        subTotal += item.unitPrice * item.quantity;
        itemDiscountTotal += item.discountAmount;
      }
      subTotal = _round2(subTotal);
      // billDiscountAmount is a separate, additional discount on top of the
      // sum of per-item discounts - matches bill.service.ts's
      // `billDiscount = itemDiscountTotal + (input.discountAmount ?? 0)`,
      // stored as the single combined Bill.discountAmount field.
      final discountAmount = _round2(itemDiscountTotal + billDiscountAmount);
      final taxable = _round2(subTotal - discountAmount);
      final taxAmount = _round2(taxable * (gstRate / 100));
      final finalAmount = _round2(taxable + taxAmount);
      final invoiceNumber = 'INV-${billRef.id.substring(0, 8).toUpperCase()}';

      // ---- WRITES ----
      final bill = FSBill(
        id: billRef.id,
        invoiceNumber: invoiceNumber,
        customerId: customerId,
        customerName: customerName,
        branchId: branchId,
        subTotal: subTotal,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        finalAmount: finalAmount,
        paymentMethod: paymentMethod,
        createdBy: createdBy,
      );
      tx.set(billRef, bill.toFirestore(isCreate: true));

      // Denormalized onto the customer doc so list/profile views can show
      // visit count, total spent, and last visit without re-reading the
      // whole bill history - see listBills()'s comment for why that matters.
      tx.update(db.collection('customers').doc(customerId), {
        'visitCount': FieldValue.increment(1),
        'totalSpent': FieldValue.increment(finalAmount),
        'lastVisitAt': FieldValue.serverTimestamp(),
      });

      for (final item in items) {
        final itemRef = billRef.collection('items').doc();
        final netAmount = _round2(item.unitPrice * item.quantity - item.discountAmount);
        final commission = _round2(netAmount * (item.commissionPct / 100));

        tx.set(
          itemRef,
          FSBillItem(
            id: itemRef.id,
            type: item.type,
            serviceId: item.serviceId,
            serviceName: item.serviceName,
            inventoryItemId: item.inventoryItemId,
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            discountAmount: item.discountAmount,
            employeeId: item.employeeId,
            employeeName: item.employeeName,
            calculatedCommission: commission,
          ).toFirestore(),
        );

        final commissionRef = db.collection('commissionRecords').doc();
        tx.set(
          commissionRef,
          FSCommissionRecord(
            id: commissionRef.id,
            employeeId: item.employeeId,
            billId: billRef.id,
            billItemId: itemRef.id,
            amount: commission,
            status: 'PENDING',
          ).toFirestore(isCreate: true),
        );

        final progressIncrement = item.type == 'SERVICE' ? netAmount : item.quantity.toDouble();
        for (final d in targetDocsByEmployee[item.employeeId] ?? []) {
          final snap = freshTargets[d.reference.path]!;
          if (!snap.exists) continue;
          final target = FSSalesTarget.fromFirestore(snap);
          // Matches bill.service.ts's startDate/endDate window exactly: not
          // yet started, or already ended, don't get progress bumped.
          if (target.startDate != null && target.startDate!.isAfter(now)) continue;
          if (target.endDate != null && target.endDate!.isBefore(todayStart)) continue;
          final newProgress = _round2(target.progressValue + progressIncrement);
          tx.update(d.reference, {
            'progressValue': newProgress,
            if (newProgress >= target.targetValue) 'status': 'ACHIEVED',
          });
        }

        if (item.type == 'PRODUCT' && item.inventoryItemId != null) {
          tx.update(db.collection('inventoryItems').doc(item.inventoryItemId), {
            'stockCount': FieldValue.increment(-item.quantity),
          });
        }
      }

      return bill;
    });
  }

  // Capped, not the whole history - a salon running for a year+ can have
  // tens of thousands of bills, and this (plus listBillItems below) used to
  // get re-read in full on every single bill/clock-in/clock-out via
  // AppDataNotifier.refresh(), which is a cost that grows every month
  // forever rather than staying flat. Everywhere this list is actually used
  // (dashboard "recent bills", bill history cards) only ever displays the
  // most recent handful anyway; a specific customer's full history goes
  // through listBillsForCustomer() instead, and their running totals are
  // denormalized onto the customer doc (see createBill's transaction).
  static const int billsPageSize = 300;

  Future<List<FSBill>> listBills() async {
    final snap = await db.collection('bills').orderBy('createdAt', descending: true).limit(billsPageSize).get();
    return snap.docs.map((d) => FSBill.fromFirestore(d)).toList();
  }

  // Used by a customer's profile view instead of filtering the capped
  // listBills() above, so an older customer's history doesn't silently
  // disappear once the salon has more than [billsPageSize] bills total.
  Future<List<FSBill>> listBillsForCustomer(String customerId, {int limit = 50}) async {
    final snap = await db
        .collection('bills')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => FSBill.fromFirestore(d)).toList();
  }

  // Single-doc re-read after createBill() so the caller can resolve the
  // FieldValue.serverTimestamp() it wrote into createdAt (the FSBill handed
  // back by the transaction itself only ever holds the client-side draft,
  // which never set createdAt) without re-fetching the whole bills list.
  Future<FSBill?> getBill(String id) async {
    final doc = await db.collection('bills').doc(id).get();
    return doc.exists ? FSBill.fromFirestore(doc) : null;
  }

  Future<List<FSBillItem>> listBillItems(String billId) async {
    final snap = await db.collection('bills').doc(billId).collection('items').get();
    return snap.docs.map(FSBillItem.fromFirestore).toList();
  }

  // --- Attendance ---
  // Doc id "{employeeId}_{yyyy-MM-dd}" reproduces the REST backend's
  // (employeeId, date) unique constraint without needing a query to check
  // "did I already clock in today".

  String attendanceDocId(String employeeId, DateTime date) =>
      '${employeeId}_${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<FSAttendanceRecord> clockIn(String employeeId) async {
    final today = DateTime.now();
    final ref = db.collection('attendanceRecords').doc(attendanceDocId(employeeId, today));
    final existing = await ref.get();
    if (existing.exists && existing.data()?['clockIn'] != null) {
      throw Exception('Already clocked in today');
    }
    await ref.set({
      'employeeId': employeeId,
      'date': Timestamp.fromDate(DateTime(today.year, today.month, today.day)),
      'clockIn': FieldValue.serverTimestamp(),
      'clockOut': null,
      'status': 'PRESENT',
    });
    return FSAttendanceRecord.fromFirestore(await ref.get());
  }

  Future<FSAttendanceRecord> clockOut(String employeeId) async {
    final today = DateTime.now();
    final ref = db.collection('attendanceRecords').doc(attendanceDocId(employeeId, today));
    final existing = await ref.get();
    if (!existing.exists || existing.data()?['clockIn'] == null) {
      throw Exception('You have not clocked in today');
    }
    if (existing.data()?['clockOut'] != null) {
      throw Exception('Already clocked out today');
    }
    await ref.update({'clockOut': FieldValue.serverTimestamp()});
    return FSAttendanceRecord.fromFirestore(await ref.get());
  }

  Future<FSAttendanceRecord> markAttendance({required String employeeId, required DateTime date, required String status}) async {
    final ref = db.collection('attendanceRecords').doc(attendanceDocId(employeeId, date));
    await ref.set({
      'employeeId': employeeId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'status': status,
    }, SetOptions(merge: true));
    return FSAttendanceRecord.fromFirestore(await ref.get());
  }

  Future<List<FSAttendanceRecord>> listAttendance({String? employeeId, int limit = 500}) async {
    Query<Map<String, dynamic>> q = db.collection('attendanceRecords');
    if (employeeId != null) q = q.where('employeeId', isEqualTo: employeeId);
    q = q.orderBy('date', descending: true).limit(limit);
    final snap = await q.get();
    return snap.docs.map(FSAttendanceRecord.fromFirestore).toList();
  }

  // --- Sales targets ---

  Future<List<FSSalesTarget>> listSalesTargets({String? employeeId}) async {
    Query<Map<String, dynamic>> q = db.collection('salesTargets');
    if (employeeId != null) q = q.where('employeeId', isEqualTo: employeeId);
    final snap = await q.get();
    return snap.docs.map(FSSalesTarget.fromFirestore).toList();
  }

  Future<FSSalesTarget> createSalesTarget(FSSalesTarget target) async {
    final ref = await db.collection('salesTargets').add(target.toFirestore());
    return FSSalesTarget.fromFirestore(await ref.get());
  }

  // --- Salary ---

  Future<List<FSSalaryRecord>> listSalaryRecords({String? employeeId}) async {
    Query<Map<String, dynamic>> q = db.collection('salaryRecords');
    if (employeeId != null) q = q.where('employeeId', isEqualTo: employeeId);
    final snap = await q.get();
    return snap.docs.map(FSSalaryRecord.fromFirestore).toList();
  }

  Future<void> createSalaryRecord(FSSalaryRecord record) => db.collection('salaryRecords').add(record.toFirestore());

  Future<void> markSalaryPaid(String id) async {
    final ref = db.collection('salaryRecords').doc(id);
    if (!(await ref.get()).exists) throw Exception('Salary record not found');
    await ref.update({'status': 'PAID'});
  }

  // Doc id "{employeeId}_{year}-{month}" (not .add()) so re-running for the
  // same employee/month/year upserts instead of duplicating - reproduces
  // Prisma's @@unique([employeeId, month, year]) without a query. Mirrors
  // backend/src/services/salary.service.ts: sum pending commissions in the
  // period, count LATE attendance in the period for the deduction, then
  // atomically write the salary record and flip those same commissions to
  // PAID so a later run never double-counts them.
  String _salaryRecordId(String employeeId, int month, int year) =>
      '${employeeId}_$year-${month.toString().padLeft(2, '0')}';

  Future<List<FSSalaryRecord>> generateSalary({required int month, required int year, String? employeeId}) async {
    final periodStart = DateTime(year, month, 1);
    final periodEnd = DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));

    List<FSEmployee> employees;
    if (employeeId != null) {
      final e = await getEmployee(employeeId);
      employees = (e == null || !e.active) ? [] : [e];
    } else {
      employees = (await listEmployees()).where((e) => e.active).toList();
    }
    if (employees.isEmpty) throw Exception('No matching active employees found');

    final settings = await getSettings();
    final results = <FSSalaryRecord>[];

    for (final employee in employees) {
      final recordId = _salaryRecordId(employee.id, month, year);
      final existing = await db.collection('salaryRecords').doc(recordId).get();
      if (existing.exists && existing.data()?['status'] == 'PAID') continue;

      final pendingSnap = await db
          .collection('commissionRecords')
          .where('employeeId', isEqualTo: employee.id)
          .where('status', isEqualTo: 'PENDING')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(periodEnd))
          .get();
      final commissionEarned = _round2(pendingSnap.docs.map(FSCommissionRecord.fromFirestore).fold(0.0, (s, c) => s + c.amount));

      final lateSnap = await db
          .collection('attendanceRecords')
          .where('employeeId', isEqualTo: employee.id)
          .where('status', isEqualTo: 'LATE')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(periodEnd))
          .get();
      final deductions = _round2(lateSnap.docs.length * settings.lateAttendancePenalty);

      final totalPaid = _round2(employee.baseSalary + commissionEarned - deductions);
      final record = FSSalaryRecord(
        id: recordId,
        employeeId: employee.id,
        month: month,
        year: year,
        baseSalary: employee.baseSalary,
        commissionEarned: commissionEarned,
        deductions: deductions,
        totalPaid: totalPaid,
        status: 'DRAFT',
      );

      await db.runTransaction((tx) async {
        // READS before WRITES, same ordering constraint as createBill().
        final freshPending = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final d in pendingSnap.docs) {
          freshPending.add(await tx.get(d.reference));
        }
        tx.set(db.collection('salaryRecords').doc(recordId), record.toFirestore());
        for (final d in freshPending) {
          if (d.exists) tx.update(d.reference, {'status': 'PAID'});
        }
      });

      results.add(record);
    }

    return results;
  }

  // --- Dashboard ---
  // Mirrors backend/src/services/dashboard.service.ts, returning the exact
  // same JSON shape so the existing DashboardSummary.fromJson (models.dart)
  // can parse it unchanged. One query for the widest window (month) instead
  // of three separate today/week/month queries - today and week are both
  // subsets of month, filtered client-side.
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);

    final results = await Future.wait([
      db.collection('bills').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart)).get(),
      db.collection('attendanceRecords').where('date', isEqualTo: Timestamp.fromDate(todayStart)).get(),
      db.collection('discountRequests').where('status', isEqualTo: 'PENDING').get(),
      db.collection('inventoryItems').get(),
    ]);

    final monthBills = results[0].docs.map((d) => FSBill.fromFirestore(d)).toList();
    final todayBills = monthBills.where((b) => b.createdAt != null && !b.createdAt!.isBefore(todayStart)).toList();
    final weekBills = monthBills.where((b) => b.createdAt != null && !b.createdAt!.isBefore(weekStart)).toList();

    double sumFinal(List<FSBill> bills) => _round2(bills.fold(0.0, (s, b) => s + b.finalAmount));
    double sumByMethod(String method) =>
        _round2(todayBills.where((b) => b.paymentMethod == method).fold(0.0, (s, b) => s + b.finalAmount));

    final todayAttendanceCount = results[1].docs.where((d) {
      final status = d.data()['status'];
      return status == 'PRESENT' || status == 'LATE';
    }).length;

    final lowStockItemCount = results[3].docs.map((d) => FSInventoryItem.fromFirestore(d)).where((i) => i.isLowStock).length;

    return {
      'todaySales': sumFinal(todayBills),
      'weekSales': sumFinal(weekBills),
      'monthSales': sumFinal(monthBills),
      'todayPaymentBreakdown': {
        'CASH': sumByMethod('CASH'),
        'CARD': sumByMethod('CARD'),
        'UPI': sumByMethod('UPI'),
      },
      'todayCustomersCount': todayBills.map((b) => b.customerId).toSet().length,
      'todayBillCount': todayBills.length,
      'todayAttendanceCount': todayAttendanceCount,
      'pendingDiscountRequests': results[2].docs.length,
      'lowStockItemCount': lowStockItemCount,
    };
  }

  // --- Commissions ---

  Future<List<FSCommissionRecord>> listCommissions({String? employeeId, int limit = 1000}) async {
    Query<Map<String, dynamic>> q = db.collection('commissionRecords');
    if (employeeId != null) q = q.where('employeeId', isEqualTo: employeeId);
    q = q.orderBy('createdAt', descending: true).limit(limit);
    final snap = await q.get();
    return snap.docs.map(FSCommissionRecord.fromFirestore).toList();
  }

  Future<void> markCommissionPaid(String id) async {
    final ref = db.collection('commissionRecords').doc(id);
    if (!(await ref.get()).exists) throw Exception('Commission record not found');
    await ref.update({'status': 'PAID'});
  }

  // --- Discount requests ---

  Future<List<FSDiscountRequest>> listDiscountRequests({String? requestedBy, int limit = 300}) async {
    Query<Map<String, dynamic>> q = db.collection('discountRequests');
    if (requestedBy != null) q = q.where('requestedBy', isEqualTo: requestedBy);
    q = q.orderBy('createdAt', descending: true).limit(limit);
    final snap = await q.get();
    return snap.docs.map(FSDiscountRequest.fromFirestore).toList();
  }

  Future<FSDiscountRequest> createDiscountRequest(FSDiscountRequest request) async {
    final ref = await db.collection('discountRequests').add(request.toFirestore(isCreate: true));
    return FSDiscountRequest.fromFirestore(await ref.get());
  }

  // Mirrors discountRequest.service.ts: only a still-PENDING request can be
  // resolved, and approving generates the random authorizedCode the
  // employee shows at checkout - matches `crypto.randomBytes(4).toString
  // ('hex').toUpperCase()`.
  Future<FSDiscountRequest> resolveDiscountRequest(String id, {required bool approve}) async {
    final ref = db.collection('discountRequests').doc(id);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('Discount request not found');
    if (doc.data()?['status'] != 'PENDING') {
      throw Exception('Only pending requests can be ${approve ? 'approved' : 'rejected'}');
    }
    if (approve) {
      final code = List.generate(4, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join().toUpperCase();
      await ref.update({'status': 'APPROVED', 'authorizedCode': code});
    } else {
      await ref.update({'status': 'REJECTED'});
    }
    return FSDiscountRequest.fromFirestore(await ref.get());
  }

  // --- Expenses ---

  Future<List<FSExpense>> listExpenses({int limit = 500}) async {
    final snap = await db.collection('expenses').orderBy('date', descending: true).limit(limit).get();
    return snap.docs.map(FSExpense.fromFirestore).toList();
  }

  Future<FSExpense> createExpense(FSExpense expense) async {
    final ref = await db.collection('expenses').add(expense.toFirestore());
    return FSExpense.fromFirestore(await ref.get());
  }
}

// Input shape for one line of createBill() - deliberately not FSBillItem
// itself, since the caller doesn't know calculatedCommission (the
// transaction computes it) but does know the employee's commission rate to
// compute it with.
class BillItemDraft {
  final String type; // SERVICE | PRODUCT
  final String? serviceId;
  final String? serviceName;
  final String? inventoryItemId;
  final String? productName;
  final String employeeId;
  final String? employeeName;
  final int quantity;
  final double unitPrice;
  final double discountAmount;
  final double commissionPct;

  BillItemDraft({
    required this.type,
    this.serviceId,
    this.serviceName,
    this.inventoryItemId,
    this.productName,
    required this.employeeId,
    this.employeeName,
    this.quantity = 1,
    required this.unitPrice,
    this.discountAmount = 0,
    required this.commissionPct,
  });
}
