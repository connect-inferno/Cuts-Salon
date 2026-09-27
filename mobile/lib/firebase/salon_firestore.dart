import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  /// How far back a delta read reaches behind the newest thing already
  /// cached.
  ///
  /// The naive watermark - "newest document I hold" - has a hole when two
  /// people bill at once. Say this device cached up to 2pm, a colleague rang
  /// up a bill at 2:05, and then this device rang up its own at 2:10. Its
  /// own write lands in its own cache, so the newest cached timestamp is now
  /// 2:10 and a delta of "after 2:10" skips straight past the colleague's
  /// 2:05 bill - which would then never appear here at all, because nothing
  /// re-reads that range.
  ///
  /// Overlapping by a day closes that: anything written in the last 24 hours
  /// is re-read, ids are deduped on merge, and the cost is one day of
  /// documents per load rather than the full page. The same buffer, for the
  /// same reason, is why the items and payments group queries below reach a
  /// day behind their oldest bill.
  static const Duration _deltaOverlap = Duration(days: 1);

  // Apps whose Firestore instance has already had persistence turned on.
  // Doing it twice throws, and SalonFirestore is constructed fresh on every
  // AppData rebuild (see AppDataNotifier.build), so the guard is per app
  // name rather than per instance.
  static final Set<String> _persistenceEnabledFor = {};

  /// Turns on the local document cache for [app], once.
  ///
  /// This is what makes the delta reads in [listBills], [listBillItemsForBills]
  /// and [listPaymentsForBills] possible: bills, their items and their
  /// payments are all append-only (firestore.rules denies update and delete
  /// on every one of them), so a document that has been read once can never
  /// change, and re-reading it on every load was pure waste.
  ///
  /// Each salon has its own FirebaseApp, and Firestore keys its IndexedDB
  /// store by project - so one salon's cache is physically a different store
  /// from another's, and a shared Vercel origin can't leak one tenant's
  /// documents into another's cache.
  ///
  /// Every failure here is survivable and deliberately swallowed: Safari in
  /// Private Browsing has no IndexedDB at all, ITP evicts script-writable
  /// storage after seven days of not visiting (see the notes in
  /// salon_auth.dart), and a second tab without synchronizeTabs would throw
  /// failed-precondition. In all of those the cache reads below simply come
  /// back empty and every query falls through to the server, which is
  /// exactly how the app behaved before any of this existed.
  static Future<void> enablePersistence(FirebaseApp app) async {
    if (!_persistenceEnabledFor.add(app.name)) return;
    final db = FirebaseFirestore.instanceFor(app: app);
    try {
      if (kIsWeb) {
        // synchronizeTabs matters here: two tabs on one origin already share
        // a Firebase Auth session (see
        // AuthController._watchForIdentityChange), so they should share one
        // cache too - in single-tab mode the second tab can't take the
        // IndexedDB lock and silently runs uncached.
        //
        // enablePersistence is deprecated in favour of
        // Settings.webPersistentTabManager, which this project's
        // cloud_firestore (5.6.12 / platform interface 6.6.12) doesn't have
        // yet - Settings there exposes only persistenceEnabled, which is
        // single-tab. Swap to the Settings form when the package is next
        // upgraded; until then this is the only multi-tab option.
        // ignore: deprecated_member_use
        await db.enablePersistence(const PersistenceSettings(synchronizeTabs: true));
      } else {
        // Mobile enables it by default; set explicitly so the intent is
        // visible and survives a default changing.
        db.settings = const Settings(persistenceEnabled: true);
      }
    } catch (e) {
      debugPrint('[Stylux] Firestore local cache unavailable, reads go to the server: $e');
    }
  }

  // --- Settings (single fixed-id document) ---

  Future<FSSettings> getSettings() async {
    try {
      final doc = await db.collection('settings').doc('main').get();
      if (!doc.exists) {
        return FSSettings(salonName: 'Stylux Salon', gstEnabled: false, gstRate: 0, lateAttendancePenalty: 0);
      }
      return FSSettings.fromFirestore(doc);
    } catch (_) {
      return FSSettings(salonName: 'Stylux Salon', gstEnabled: false, gstRate: 0, lateAttendancePenalty: 0);
    }
  }

  Future<void> updateSettings(Map<String, dynamic> changes) =>
      db.collection('settings').doc('main').set(changes, SetOptions(merge: true));

  // --- Branches ---

  // --- Catalog freshness: removed, deliberately ---
  //
  // There was a version-stamp gate here: a `catalogVersion` counter on the
  // settings doc, bumped by every catalog write, compared against the cached
  // copy to decide whether the ~54 catalog documents could be served from
  // cache. It saved ~54 reads a load and it was WRONG - it shipped a team
  // roster two employees short.
  //
  // The premise was that every catalog write goes through this class. It
  // does not. CLAUDE.md's own onboarding says to create the owner's
  // employees/{uid} document by hand in the Firebase console, and anything
  // written that way never bumps the counter - so the gate keeps serving a
  // stale cache indefinitely, with no error and nothing in the UI to say so.
  // A partial cache passes an isNotEmpty check just as happily as a
  // complete one.
  //
  // If this is worth revisiting: gate on a count() aggregation instead (one
  // read per collection, catches out-of-band adds and deletes), and accept
  // that an out-of-band EDIT with an unchanged count would still slip
  // through. Given `services` carries the prices bills are built from, that
  // residual risk is why this was not simply patched.

  Future<List<FSBranch>> listBranches() async {
    final snap = await db.collection('branches').get();
    return snap.docs.map(FSBranch.fromFirestore).toList();
  }

  // No read-back after the add(): nothing written here is server-generated
  // (FSBranch has no serverTimestamp field), so the doc that would come back
  // is exactly what went in plus the id we already hold. Same reasoning for
  // createServiceCategory/createService/createInventoryItem/createSalesTarget
  // /createExpense below; the creates that DO write a serverTimestamp
  // (customers, bills, payments, discount requests) still re-read, because
  // there the round trip is the only way to learn createdAt.
  Future<FSBranch> createBranch({required String name, String? address, String? phone}) async {
    final ref = await db.collection('branches').add(
          FSBranch(id: '', name: name, address: address, phone: phone, active: true).toFirestore(),
        );
    return FSBranch(id: ref.id, name: name, address: address, phone: phone, active: true);
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

  /// The whole client directory, read forward from the local cache.
  ///
  /// This was the single largest read in the app and the only one with no
  /// ceiling at all: every client the salon has ever taken, on every load,
  /// growing forever. At 10,000 clients it cost more than everything else on
  /// a load put together.
  ///
  /// Customers are not immutable the way bills are - billing bumps
  /// visitCount, totalSpent and outstandingBalance - so the delta keys on an
  /// `updatedAt` stamp that every write path sets (see [customerTouch])
  /// rather than on creation order. The cached copy of a client nobody has
  /// touched is still correct by definition, because the only thing that
  /// could have changed it would have stamped it.
  ///
  /// Deliberately not a name/phone index document: visitCount, totalSpent,
  /// lastVisitAt and outstandingBalance are read by the client lists on both
  /// dashboards, the archived list and the dues view, so a trimmed index
  /// would have to be re-joined against full documents in four places - and
  /// a *fat* index would be rewritten by every bill, since those same fields
  /// change on every bill, which is exactly the write-contention an index is
  /// supposed to avoid.
  ///
  /// With no usable cache the watermark is null, the query is unbounded, and
  /// this reads the full collection exactly as it always did.
  Future<List<FSCustomer>> listCustomers() async {
    final ordering = db.collection('customers').orderBy('createdAt', descending: true);
    final cached = await _cachedDocs(ordering);

    DateTime? newest;
    for (final doc in cached) {
      final at = _timestampOf(doc, 'updatedAt');
      if (at != null && (newest == null || at.isAfter(newest))) newest = at;
    }

    // Documents written before updatedAt existed carry none, so they never
    // raise the watermark - which is right: they also can't have changed
    // since, or the change would have stamped them.
    final fresh = newest == null
        ? await ordering.get(const GetOptions(source: Source.server))
        : await db
            .collection('customers')
            .where('updatedAt', isGreaterThan: Timestamp.fromDate(newest.subtract(_deltaOverlap)))
            .get(const GetOptions(source: Source.server));

    return _mergeNewestFirst(
      fresh.docs,
      cached,
      FSCustomer.fromFirestore,
      (c) => c.id,
      (c) => c.createdAt,
      null,
    );
  }

  Future<FSCustomer> createCustomer(FSCustomer customer) async {
    final ref = await db.collection('customers').add(customer.toFirestore(isCreate: true));
    return FSCustomer.fromFirestore(await ref.get());
  }

  /// Every field that can change on a customer document must go through a
  /// write that carries this stamp, or [listCustomers]'s delta will not see
  /// the change and the directory will serve a stale copy from cache
  /// indefinitely. That means here, [createCustomer], and the two stat bumps
  /// inside createBill's and recordPayment's transactions.
  static Map<String, dynamic> customerTouch(Map<String, dynamic> changes) => {
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Future<void> updateCustomer(String id, Map<String, dynamic> changes) =>
      db.collection('customers').doc(id).update(customerTouch(changes));

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
    return FSServiceCategory(id: ref.id, name: name);
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
    return FSService(
      id: ref.id,
      name: service.name,
      price: service.price,
      categoryId: service.categoryId,
      categoryName: service.categoryName,
    );
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
    return FSInventoryItem(
      id: ref.id,
      sku: item.sku,
      name: item.name,
      category: item.category,
      price: item.price,
      costPrice: item.costPrice,
      stockCount: item.stockCount,
      minAlertThreshold: item.minAlertThreshold,
    );
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
  Future<FSCreatedBill> createBill({
    required String customerId,
    required String customerName,
    required String branchId,
    required String paymentMethod,
    required String createdBy,
    required double gstRate,
    required List<BillItemDraft> items,
    double billDiscountAmount = 0,
    /// What the client actually handed over now. null means "the whole
    /// bill", which is the ordinary paid-in-full case; 0 means they're
    /// paying entirely later. Clamped to the computed total below, since the
    /// caller can't know finalAmount until the tax maths runs in here.
    double? amountPaidNow,
  }) async {
    if (items.isEmpty) throw Exception('A bill must have at least one item');
    final billRef = db.collection('bills').doc();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // One query per distinct employee on the bill, issued together: these
    // are independent of each other, and awaiting them in the loop made a
    // three-stylist bill three serial round trips before the transaction
    // could even start.
    final targetLookups = <String, String>{};
    for (final item in items) {
      targetLookups.putIfAbsent(
        item.employeeId,
        () => item.type == 'SERVICE' ? 'SERVICE_VOLUME' : 'PRODUCT_SALES_COUNT',
      );
    }
    final targetSnaps = await Future.wait(targetLookups.entries.map((e) => db
        .collection('salesTargets')
        .where('employeeId', isEqualTo: e.key)
        .where('type', isEqualTo: e.value)
        .where('status', isEqualTo: 'ACTIVE')
        .get()));
    final targetDocsByEmployee = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{
      for (var i = 0; i < targetLookups.length; i++)
        targetLookups.keys.elementAt(i): targetSnaps[i].docs,
    };

    return db.runTransaction<FSCreatedBill>((tx) async {
      // Built fresh per attempt, not outside the closure - runTransaction
      // re-runs this on contention, and anything hoisted out would
      // accumulate a duplicate set on every retry.
      final createdItems = <FSBillItem>[];
      final createdCommissions = <FSCommissionRecord>[];
      final stockDeltas = <String, int>{};
      final updatedTargets = <String, FSSalesTarget>{};
      // Target path -> progress so far within this bill, so multiple lines
      // hitting the same target add up instead of overwriting each other.
      final runningProgress = <String, double>{};
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
      final amountPaid = _round2(
        amountPaidNow == null ? finalAmount : amountPaidNow.clamp(0, finalAmount),
      );
      final amountDue = _round2(finalAmount - amountPaid);

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
        amountPaid: amountPaid,
        createdBy: createdBy,
      );
      tx.set(billRef, bill.toFirestore(isCreate: true));

      // Roll this bill into its day's totals, so the dashboard can read ~37
      // small docs instead of every bill raised in the last five weeks. See
      // dailyStatsDocId and getDashboardSummary.
      //
      // Keyed on the client clock rather than the bill's serverTimestamp: a
      // transaction can't read back its own serverTimestamp to decide which
      // day doc to touch, and the two only disagree for a bill rung up
      // within seconds of midnight.
      tx.set(
        db.collection('dailyStats').doc(dailyStatsDocId(todayStart)),
        {
          'date': Timestamp.fromDate(todayStart),
          'sales': FieldValue.increment(finalAmount),
          'billCount': FieldValue.increment(1),
          'outstanding': FieldValue.increment(amountDue),
          // Bucketed by the bill's own method and incremented by what was
          // actually collected, which is what the pre-rollup query did.
          // A PENDING bill lands in no bucket, by design - see
          // getDashboardSummary's note on billed vs received.
          if (_isTillMethod(paymentMethod)) 'collected_$paymentMethod': FieldValue.increment(amountPaid),
          // arrayUnion, so a client billed twice in a day is still one
          // visitor - the figure is "distinct clients", not "bills".
          'customerIds': FieldValue.arrayUnion([customerId]),
        },
        SetOptions(merge: true),
      );

      // Denormalized onto the customer doc so list/profile views can show
      // visit count, total spent, and last visit without re-reading the
      // whole bill history - see listBills()'s comment for why that matters.
      tx.update(db.collection('customers').doc(customerId), customerTouch({
        'visitCount': FieldValue.increment(1),
        // totalSpent tracks what they were billed, not what they've handed
        // over - an unpaid bill still counts as business done, and the money
        // still owed is tracked separately below.
        'totalSpent': FieldValue.increment(finalAmount),
        if (amountDue > 0) 'outstandingBalance': FieldValue.increment(amountDue),
        'lastVisitAt': FieldValue.serverTimestamp(),
      }));

      for (final item in items) {
        final itemRef = billRef.collection('items').doc();
        final netAmount = _round2(item.unitPrice * item.quantity - item.discountAmount);
        final commission = _round2(netAmount * (item.commissionPct / 100));

        final billItem = FSBillItem(
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
        );
        tx.set(itemRef, billItem.toFirestore());
        createdItems.add(billItem);

        final commissionRef = db.collection('commissionRecords').doc();
        final commissionRecord = FSCommissionRecord(
          id: commissionRef.id,
          employeeId: item.employeeId,
          billId: billRef.id,
          billItemId: itemRef.id,
          amount: commission,
          status: 'PENDING',
        );
        tx.set(commissionRef, commissionRecord.toFirestore(isCreate: true));
        createdCommissions.add(commissionRecord);

        final progressIncrement = item.type == 'SERVICE' ? netAmount : item.quantity.toDouble();
        for (final d in targetDocsByEmployee[item.employeeId] ?? []) {
          final snap = freshTargets[d.reference.path]!;
          if (!snap.exists) continue;
          final target = FSSalesTarget.fromFirestore(snap);
          // Matches bill.service.ts's startDate/endDate window exactly: not
          // yet started, or already ended, don't get progress bumped.
          if (target.startDate != null && target.startDate!.isAfter(now)) continue;
          if (target.endDate != null && target.endDate!.isBefore(todayStart)) continue;
          // Accumulated across lines, not recomputed from the snapshot each
          // time. freshTargets holds the state at transaction start, so two
          // lines by the same stylist both read the same progressValue and
          // the second tx.update overwrote the first - a two-service bill
          // moved the target by one of its lines instead of both.
          final base = runningProgress[d.reference.path] ?? target.progressValue;
          final newProgress = _round2(base + progressIncrement);
          runningProgress[d.reference.path] = newProgress;
          final achieved = newProgress >= target.targetValue;
          tx.update(d.reference, {
            'progressValue': newProgress,
            if (achieved) 'status': 'ACHIEVED',
          });
          updatedTargets[target.id] = FSSalesTarget(
            id: target.id,
            employeeId: target.employeeId,
            type: target.type,
            targetValue: target.targetValue,
            progressValue: newProgress,
            startDate: target.startDate,
            endDate: target.endDate,
            status: achieved ? 'ACHIEVED' : target.status,
          );
        }

        if (item.type == 'PRODUCT' && item.inventoryItemId != null) {
          tx.update(db.collection('inventoryItems').doc(item.inventoryItemId), {
            'stockCount': FieldValue.increment(-item.quantity),
          });
          // Accumulated for the same reason: two lines of the same product
          // decrement it twice, and the caller patches by the total.
          stockDeltas[item.inventoryItemId!] =
              (stockDeltas[item.inventoryItemId!] ?? 0) + item.quantity;
        }
      }

      return FSCreatedBill(
        bill: bill,
        items: createdItems,
        commissions: createdCommissions,
        stockDeltas: stockDeltas,
        updatedTargets: updatedTargets,
      );
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

  /// The newest [billsPageSize] bills, read forward from the local cache.
  ///
  /// A bill is immutable once written, so anything already cached is still
  /// correct and only bills raised since the last load need fetching. The
  /// cached page costs nothing; the server query is bounded to what's new,
  /// which on a return visit is usually a handful of documents and used to
  /// be the full 300 every single time.
  ///
  /// With no usable cache - first load on this browser, Safari having
  /// evicted it, persistence unavailable - the watermark is null, the server
  /// query is unbounded and this behaves exactly like the plain page read it
  /// replaced.
  Future<List<FSBill>> listBills() async {
    final cached = await _cachedDocs(
      db.collection('bills').orderBy('createdAt', descending: true).limit(billsPageSize),
    );

    // Newest cached bill bounds the delta. Bills with no createdAt yet (the
    // serverTimestamp hasn't resolved on this client) are ignored for the
    // watermark, so one can never push it past bills we haven't seen.
    DateTime? newest;
    for (final doc in cached) {
      final at = _timestampOf(doc, 'createdAt');
      if (at != null && (newest == null || at.isAfter(newest))) newest = at;
    }

    Query<Map<String, dynamic>> q = db.collection('bills').orderBy('createdAt', descending: true);
    if (newest != null) {
      q = q.where('createdAt', isGreaterThan: Timestamp.fromDate(newest.subtract(_deltaOverlap)));
    }
    final fresh = await q.limit(billsPageSize).get(const GetOptions(source: Source.server));

    return _mergeNewestFirst(
      fresh.docs,
      cached,
      FSBill.fromFirestore,
      (b) => b.id,
      (b) => b.createdAt,
      billsPageSize,
    );
  }

  /// Runs [q] against the local cache only, returning nothing if there isn't
  /// one. Never throws: an unavailable cache is a cost question, not a
  /// correctness one, and every caller falls through to the server.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _cachedDocs(
    Query<Map<String, dynamic>> q,
  ) async {
    try {
      final snap = await q.get(const GetOptions(source: Source.cache));
      return snap.docs;
    } catch (_) {
      return const [];
    }
  }

  static DateTime? _timestampOf(QueryDocumentSnapshot<Map<String, dynamic>> doc, String field) {
    final raw = doc.data()[field];
    return raw is Timestamp ? raw.toDate() : null;
  }

  /// Folds a server delta over a cached page: newest first, one entry per id
  /// with the server's copy winning, capped at [limit] when one is given
  /// (null for collections that are read whole, like the client directory).
  static List<T> _mergeNewestFirst<T>(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> fresh,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cached,
    T Function(QueryDocumentSnapshot<Map<String, dynamic>>) parse,
    String Function(T) idOf,
    DateTime? Function(T) dateOf,
    int? limit,
  ) {
    final byId = <String, T>{};
    // Cached first so a server copy of the same id overwrites it - the two
    // overlap whenever a bill was written by this client and is already in
    // its own cache.
    for (final doc in [...cached, ...fresh]) {
      final parsed = parse(doc);
      byId[idOf(parsed)] = parsed;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final at = dateOf(a);
        final bt = dateOf(b);
        // Undated rows sort newest: a serverTimestamp that hasn't resolved
        // belongs to something just written.
        if (at == null && bt == null) return 0;
        if (at == null) return -1;
        if (bt == null) return 1;
        return bt.compareTo(at);
      });
    if (limit == null || merged.length <= limit) return merged;
    return merged.sublist(0, limit);
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

  // Fetches the items for a whole page of bills.
  //
  // The naive version was one subcollection read per bill, so a login with
  // billsPageSize (300) bills fired 300 round trips before the dashboard
  // could paint. This does it with a single collectionGroup range query over
  // the denormalized items.billCreatedAt (see FSBillItem.toFirestore), which
  // is why firestore.rules carries a `/{path=**}/items/{itemId}` read rule and
  // firestore.indexes.json a COLLECTION_GROUP override for that field.
  //
  // Two deliberate fallbacks, because neither can be assumed on a project
  // that hasn't had the new rules/index deployed yet, or whose older items
  // predate billCreatedAt:
  //   - the whole query failing (missing index, rule not deployed) drops back
  //     to the per-bill reads wholesale;
  //   - any individual bill the query returned nothing for is re-read on its
  //     own. A bill always has at least one item (createBill rejects an empty
  //     one), so "no items" reliably means "not covered by the query" rather
  //     than "genuinely empty".
  Future<Map<String, List<FSBillItem>>> listBillItemsForBills(List<FSBill> bills) async {
    if (bills.isEmpty) return {};

    final wanted = {for (final b in bills) b.id};
    final byBill = <String, List<FSBillItem>>{};

    // bills come back newest-first, so the oldest in the page bounds the
    // range. The buffer absorbs any skew between the bill's serverTimestamp
    // and its items' - they are written in one transaction, but a day of
    // slack costs nothing and guarantees no item is missed at the boundary.
    final timestamps = bills.map((b) => b.createdAt).whereType<DateTime>().toList();
    if (timestamps.isNotEmpty) {
      final oldest = timestamps.reduce((a, b) => a.isBefore(b) ? a : b);
      final from = Timestamp.fromDate(oldest.subtract(const Duration(days: 1)));
      // Items are immutable like their bills, so the cache is read first and
      // the server is asked only for what it doesn't already hold. Both
      // queries share the same lower bound; the server's upper bound starts
      // where the cache leaves off.
      final cached = await _cachedDocs(
        db.collectionGroup('items').where('billCreatedAt', isGreaterThanOrEqualTo: from),
      );
      DateTime? newestCached;
      for (final doc in cached) {
        final at = _timestampOf(doc, 'billCreatedAt');
        if (at != null && (newestCached == null || at.isAfter(newestCached))) newestCached = at;
      }

      try {
        final Query<Map<String, dynamic>> q = db.collectionGroup('items').where(
              'billCreatedAt',
              isGreaterThanOrEqualTo:
                  newestCached == null ? from : Timestamp.fromDate(newestCached.subtract(_deltaOverlap)),
            );
        final snap = await q.get(const GetOptions(source: Source.server));
        for (final doc in [...cached, ...snap.docs]) {
          final billId = doc.reference.parent.parent?.id;
          if (billId == null || !wanted.contains(billId)) continue;
          final items = byBill[billId] ??= [];
          // The two results overlap at the boundary bill, so dedupe by id.
          final item = FSBillItem.fromFirestore(doc);
          items.removeWhere((existing) => existing.id == item.id);
          items.add(item);
        }
      } catch (e) {
        // Index or rule not deployed yet - fall through to per-bill reads.
        debugPrint('[Stylux] bill items collectionGroup query unavailable, falling back per bill: $e');
        byBill.clear();
      }
    }

    final missing = bills.where((b) => (byBill[b.id] ?? const []).isEmpty).toList();
    if (missing.isNotEmpty) {
      final fetched = await Future.wait(missing.map((b) => listBillItems(b.id)));
      for (var i = 0; i < missing.length; i++) {
        byBill[missing[i].id] = fetched[i];
      }
    }

    return byBill;
  }

  // --- Payments (settling a "pay later" balance) ---

  /// Records money collected against an already-raised bill and draws the
  /// client's outstanding balance down by the same amount, in one
  /// transaction so the ledger and the denormalized balance can't diverge.
  ///
  /// The bill is immutable, so this never touches it - the balance is
  /// [FSBill.finalAmount] minus [FSBill.amountPaid] minus everything in this
  /// subcollection.
  Future<FSPayment> recordPayment({
    required String billId,
    required double amount,
    required String method,
    required String receivedBy,
    String? note,
  }) async {
    if (amount <= 0) throw Exception('Payment amount must be greater than zero');

    final billRef = db.collection('bills').doc(billId);
    final paymentRef = billRef.collection('payments').doc();

    await db.runTransaction((tx) async {
      final billDoc = await tx.get(billRef);
      if (!billDoc.exists) throw Exception('Bill not found');
      final bill = FSBill.fromFirestore(billDoc);

      // Sum what's already been settled so an over-payment is rejected here
      // rather than quietly pushing the customer's balance negative.
      final settled = await billRef.collection('payments').get();
      final alreadyPaid = _round2(
        bill.amountPaid +
            settled.docs.fold(0.0, (acc, d) => acc + ((d.data()['amount'] as num?)?.toDouble() ?? 0)),
      );
      final due = _round2(bill.finalAmount - alreadyPaid);
      if (due <= 0) throw Exception('This bill is already fully paid');
      if (amount - due > 0.009) {
        throw Exception('Only ₹${due.toStringAsFixed(0)} is outstanding on this bill');
      }

      final applied = _round2(amount);
      tx.set(
        paymentRef,
        FSPayment(
          id: paymentRef.id,
          billId: billId,
          amount: applied,
          method: method,
          receivedBy: receivedBy,
          note: note,
        ).toFirestore(isCreate: true),
      );
      tx.update(db.collection('customers').doc(bill.customerId), customerTouch({
        'outstandingBalance': FieldValue.increment(-applied),
      }));

      // Draw down the rollup for the day the *bill* was raised, not today.
      // The dashboard's outstanding figure is "billed today and not yet
      // collected", so settling a bill from last Tuesday belongs to last
      // Tuesday's doc - which is exactly what the bills-counting path
      // computed by re-reading bill.amountPaid. Skipped when the bill has no
      // createdAt (never observed, since it's set on write) because there'd
      // be no day to attribute it to.
      final billDay = bill.createdAt;
      if (billDay != null) {
        final day = DateTime(billDay.year, billDay.month, billDay.day);
        tx.set(
          db.collection('dailyStats').doc(dailyStatsDocId(day)),
          {
            'date': Timestamp.fromDate(day),
            'outstanding': FieldValue.increment(-applied),
            // Money reaching the till later still shows under the bill's own
            // method, matching the old sumByMethod - which bucketed on
            // bill.paymentMethod and summed its running amountPaid. A
            // PENDING bill stays in no bucket however it's settled.
            if (_isTillMethod(bill.paymentMethod))
              'collected_${bill.paymentMethod}': FieldValue.increment(applied),
          },
          SetOptions(merge: true),
        );
      }
    });

    return FSPayment.fromFirestore(await paymentRef.get());
  }

  Future<List<FSPayment>> listPaymentsForBill(String billId) async {
    final snap = await db.collection('bills').doc(billId).collection('payments').get();
    return snap.docs.map(FSPayment.fromFirestore).toList();
  }

  /// Batched equivalent of [listPaymentsForBill] for a whole page of bills -
  /// same collection-group trick (and the same rule carve-out) that
  /// [listBillItemsForBills] uses, for the same N+1 reason.
  ///
  /// Unlike items, most bills have no payments at all, so the per-bill
  /// fallback is deliberately limited to bills that actually still owe
  /// something - otherwise a failed group query would fan out into one read
  /// per bill on every single load.
  Future<Map<String, List<FSPayment>>> listPaymentsForBills(List<FSBill> bills) async {
    if (bills.isEmpty) return {};

    final wanted = {for (final b in bills) b.id};
    final byBill = <String, List<FSPayment>>{};
    var groupQueryWorked = false;

    final timestamps = bills.map((b) => b.createdAt).whereType<DateTime>().toList();
    if (timestamps.isNotEmpty) {
      final oldest = timestamps.reduce((a, b) => a.isBefore(b) ? a : b);
      final from = Timestamp.fromDate(oldest.subtract(const Duration(days: 1)));
      // Payments are append-only too, but unlike items they are NOT tied to
      // their bill's date: a balance from three weeks ago can be settled
      // this afternoon. So the watermark here is the newest receivedAt in
      // the cache, not anything about the bills - a delta on receivedAt
      // picks up late settlements against old bills exactly as a full read
      // of the window would.
      final cached = await _cachedDocs(
        db.collectionGroup('payments').where('receivedAt', isGreaterThanOrEqualTo: from),
      );
      DateTime? newestCached;
      for (final doc in cached) {
        final at = _timestampOf(doc, 'receivedAt');
        if (at != null && (newestCached == null || at.isAfter(newestCached))) newestCached = at;
      }

      try {
        final snap = await db
            .collectionGroup('payments')
            .where('receivedAt',
                isGreaterThanOrEqualTo:
                    newestCached == null ? from : Timestamp.fromDate(newestCached.subtract(_deltaOverlap)))
            .get(const GetOptions(source: Source.server));
        for (final doc in [...cached, ...snap.docs]) {
          final billId = doc.reference.parent.parent?.id;
          if (billId == null || !wanted.contains(billId)) continue;
          final payments = byBill[billId] ??= [];
          final payment = FSPayment.fromFirestore(doc);
          payments.removeWhere((existing) => existing.id == payment.id);
          payments.add(payment);
        }
        groupQueryWorked = true;
      } catch (e) {
        debugPrint('[Stylux] payments collectionGroup query unavailable, falling back per bill: $e');
        byBill.clear();
      }
    }

    if (!groupQueryWorked) {
      final owing = bills.where((b) => b.finalAmount - b.amountPaid > 0.009).toList();
      if (owing.isNotEmpty) {
        final fetched = await Future.wait(owing.map((b) => listPaymentsForBill(b.id)));
        for (var i = 0; i < owing.length; i++) {
          byBill[owing[i].id] = fetched[i];
        }
      }
    }

    return byBill;
  }


  // --- Attendance ---
  // Doc id "{employeeId}_{yyyy-MM-dd}" reproduces the REST backend's
  // (employeeId, date) unique constraint without needing a query to check
  // "did I already clock in today".

  String attendanceDocId(String employeeId, DateTime date) =>
      '${employeeId}_${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<FSAttendanceRecord> clockIn(String employeeId, {Map<String, dynamic> location = const {}}) async {
    final today = DateTime.now();
    final ref = db.collection('attendanceRecords').doc(attendanceDocId(employeeId, today));
    final existing = await ref.get();
    if (existing.exists && existing.data()?['clockIn'] != null) {
      throw Exception('Already clocked in today');
    }
    // Two paths on purpose. If the owner has already confirmed the roster
    // there is a status-only record for today, and a blanket set() would
    // overwrite the status they chose - which the rules now refuse anyway,
    // since staff may write their own clock times and nothing else.
    if (existing.exists) {
      await ref.update({'clockIn': FieldValue.serverTimestamp(), ...location});
    } else {
      await ref.set({
        'employeeId': employeeId,
        'date': Timestamp.fromDate(DateTime(today.year, today.month, today.day)),
        'clockIn': FieldValue.serverTimestamp(),
        'clockOut': null,
        'status': 'PRESENT',
        ...location,
      });
    }
    return FSAttendanceRecord.fromFirestore(await ref.get());
  }

  Future<FSAttendanceRecord> clockOut(String employeeId, {Map<String, dynamic> location = const {}}) async {
    final today = DateTime.now();
    final ref = db.collection('attendanceRecords').doc(attendanceDocId(employeeId, today));
    final existing = await ref.get();
    if (!existing.exists || existing.data()?['clockIn'] == null) {
      throw Exception('You have not clocked in today');
    }
    if (existing.data()?['clockOut'] != null) {
      throw Exception('Already clocked out today');
    }
    await ref.update({'clockOut': FieldValue.serverTimestamp(), ...location});
    return FSAttendanceRecord.fromFirestore(await ref.get());
  }

  /// Sets one day's status for one employee, leaving any clock times alone.
  ///
  /// An owner setting a day's status IS the confirmation of that day - it is
  /// the owner saying the person was there - so this stamps `confirmed`
  /// alongside the status. Nothing else sets it: a self-punch leaves it
  /// false, and the rules refuse to let staff write it at all.
  ///
  /// Returns what the merged doc now holds without reading it back, because
  /// confirming a roster writes one of these per employee and a read-back
  /// each time would double the cost of the biggest bulk action in the app.
  /// `confirmedAt` is the one field the caller cannot know - it is a server
  /// timestamp - so the returned record leaves it null until the next load.
  /// Nothing renders it; the boolean is what screens and payroll read.
  Future<FSAttendanceRecord> markAttendance({
    required String employeeId,
    required DateTime date,
    required String status,
    required String confirmedBy,
    DateTime? existingClockIn,
    DateTime? existingClockOut,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final ref = db.collection('attendanceRecords').doc(attendanceDocId(employeeId, date));
    await ref.set({
      'employeeId': employeeId,
      'date': Timestamp.fromDate(day),
      'status': status,
      'confirmed': true,
      'confirmedBy': confirmedBy,
      'confirmedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return FSAttendanceRecord(
      id: ref.id,
      employeeId: employeeId,
      date: day,
      clockIn: existingClockIn,
      clockOut: existingClockOut,
      status: status,
      confirmed: true,
      confirmedBy: confirmedBy,
    );
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
    return FSSalesTarget(
      id: ref.id,
      employeeId: target.employeeId,
      type: target.type,
      targetValue: target.targetValue,
      progressValue: target.progressValue,
      startDate: target.startDate,
      endDate: target.endDate,
      status: target.status,
    );
  }

  // --- Salary ---

  /// Salary slips for the recent period, newest first.
  ///
  /// This was the one query in the app with no bound at all - an owner read
  /// every slip ever written, for the whole team, so the cost grew with the
  /// salon's age rather than its size.
  ///
  /// Bounded by period rather than by row count on purpose: an owner's query
  /// spans every employee, so a flat `limit` would cut one person's history
  /// shorter as the roster grew - six staff and `limit(24)` is four months,
  /// not two years. A year window gives everyone the same span whatever the
  /// headcount, and the screens only ever show recent months anyway.
  ///
  /// [FSSalaryRecord] keeps month and year as separate integers with no
  /// timestamp, hence the two-field ordering and its composite indexes in
  /// firestore.indexes.json. Until those finish building the query throws,
  /// so this falls back to the old unbounded read rather than leaving
  /// Payroll broken - same shape as listPendingCommissions.
  Future<List<FSSalaryRecord>> listSalaryRecords({String? employeeId}) async {
    final cutoffYear = DateTime.now().year - 2;

    Query<Map<String, dynamic>> windowed = db.collection('salaryRecords');
    if (employeeId != null) windowed = windowed.where('employeeId', isEqualTo: employeeId);
    windowed = windowed
        .where('year', isGreaterThanOrEqualTo: cutoffYear)
        .orderBy('year', descending: true)
        .orderBy('month', descending: true);

    try {
      final snap = await windowed.get();
      return snap.docs.map(FSSalaryRecord.fromFirestore).toList();
    } catch (e) {
      debugPrint('[Stylux] salary period index unavailable, reading unbounded: $e');
      Query<Map<String, dynamic>> all = db.collection('salaryRecords');
      if (employeeId != null) all = all.where('employeeId', isEqualTo: employeeId);
      final snap = await all.get();
      return snap.docs.map(FSSalaryRecord.fromFirestore).toList();
    }
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
      // Only days the owner has confirmed. An unconfirmed LATE is a claim
      // nobody has vouched for, and docking pay on one would be exactly the
      // "rollup drifted, wage came out wrong" failure this design exists to
      // avoid. Filtered here rather than in the query: the LATE documents
      // are already fetched, so this costs nothing and needs no new index.
      final confirmedLate = lateSnap.docs.where((d) => d.data()['confirmed'] == true).length;
      final deductions = _round2(confirmedLate * settings.lateAttendancePenalty);

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

  // --- Daily rollups ---
  //
  // One doc per calendar day holding that day's billing totals, written by
  // createBill's transaction and drawn down by recordPayment. The dashboard
  // needs today, the trailing week and the month to date; reading those from
  // the bills collection meant pulling every bill raised in ~37 days on
  // every load *and* after every bill - over a thousand documents for a
  // salon doing thirty bills a day. Thirty-seven rollup docs answer the same
  // question, and the write that maintains them is free at these volumes.

  static String dailyStatsDocId(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  /// Whether a bill's payment method represents money in the till today.
  /// PENDING doesn't - nothing was handed over - and neither would any
  /// method added later without a matching `collected_` field.
  static bool _isTillMethod(String method) =>
      method == 'CASH' || method == 'CARD' || method == 'UPI';

  /// The first day that has a rollup doc, or null if none exist.
  ///
  /// Salons provisioned before rollups existed have bills with no matching
  /// day docs, and a summary built from those would silently under-report
  /// real revenue. One cheap doc read tells [getDashboardSummary] whether
  /// the rollups actually cover the window it needs, or whether it has to
  /// fall back to counting bills. Once the oldest rollup is more than five
  /// weeks old the fallback can never trigger again.
  Future<DateTime?> _earliestRollupDay() async {
    final snap = await db.collection('dailyStats').orderBy('date').limit(1).get();
    if (snap.docs.isEmpty) return null;
    final raw = snap.docs.first.data()['date'];
    return raw is Timestamp ? raw.toDate() : null;
  }

  // --- Dashboard ---
  // Mirrors backend/src/services/dashboard.service.ts, returning the exact
  // same JSON shape so the existing DashboardSummary.fromJson (models.dart)
  // can parse it unchanged. One query for the widest window (month) instead
  // of three separate today/week/month queries - today and week are both
  // subsets of month, filtered client-side.
  //
  // The three non-bill figures are passed in rather than queried, because
  // every caller has already loaded the collections they come from and was
  // paying for them twice:
  //   - lowStockItemCount re-ran `inventoryItems.get()`, the identical
  //     unfiltered read listInventory() had just done (in loadAppData, and
  //     again concurrently with it inside createBill's own Future.wait);
  //   - todayAttendanceCount and pendingDiscountRequests re-queried subsets
  //     of listAttendance()/listDiscountRequests(), both of which an owner
  //     loads unfiltered.
  // Deriving them caller-side is exact for any salon under the page caps on
  // those two lists (500 attendance rows, 300 discount requests) - and the
  // owner dashboard already derived pendingDiscountRequests that way for its
  // own bell badge, so this also removes a second source for that number.
  Future<Map<String, dynamic>> getDashboardSummary({
    required int todayAttendanceCount,
    required int pendingDiscountRequests,
    required int lowStockItemCount,
  }) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);
    // One query has to cover both windows, so it starts at whichever is
    // earlier. Anchoring it on monthStart alone silently truncated weekSales
    // for the first six days of every month (on the 2nd, the trailing-7-day
    // figure only ever saw the 1st and the 2nd, so weekSales == monthSales).
    final queryStart = weekStart.isBefore(monthStart) ? weekStart : monthStart;

    // Rollups first, when they cover the whole window.
    final earliestRollup = await _earliestRollupDay();
    if (earliestRollup != null && !earliestRollup.isAfter(queryStart)) {
      return _summaryFromRollups(
        queryStart: queryStart,
        todayStart: todayStart,
        weekStart: weekStart,
        monthStart: monthStart,
        todayAttendanceCount: todayAttendanceCount,
        pendingDiscountRequests: pendingDiscountRequests,
        lowStockItemCount: lowStockItemCount,
      );
    }

    // Otherwise count the bills, exactly as before rollups existed - this is
    // the path a salon takes for its first five weeks after the rollups ship,
    // and the only path one takes if they were never written.
    final snap = await db
        .collection('bills')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart))
        .get();

    final windowBills = snap.docs.map((d) => FSBill.fromFirestore(d)).toList();
    final monthBills = windowBills.where((b) => b.createdAt != null && !b.createdAt!.isBefore(monthStart)).toList();
    final todayBills = windowBills.where((b) => b.createdAt != null && !b.createdAt!.isBefore(todayStart)).toList();
    final weekBills = windowBills.where((b) => b.createdAt != null && !b.createdAt!.isBefore(weekStart)).toList();

    double sumFinal(List<FSBill> bills) => _round2(bills.fold(0.0, (s, b) => s + b.finalAmount));
    // The payment breakdown is money actually in the till, so it sums what
    // was collected, not what was billed - a "pay later" bill contributes
    // only the part handed over at the counter (and a wholly unpaid one
    // contributes nothing, since its method is PENDING). todaySales above
    // stays on finalAmount: that's revenue booked, which is a different
    // question from cash received.
    double sumByMethod(String method) => _round2(
          todayBills.where((b) => b.paymentMethod == method).fold(0.0, (s, b) => s + b.amountPaid),
        );

    return {
      'todaySales': sumFinal(todayBills),
      'weekSales': sumFinal(weekBills),
      'monthSales': sumFinal(monthBills),
      'todayPaymentBreakdown': {
        'CASH': sumByMethod('CASH'),
        'CARD': sumByMethod('CARD'),
        'UPI': sumByMethod('UPI'),
      },
      // Billed today but not collected today - the counterpart to the
      // breakdown above, so the dashboard can show both sides.
      'todayOutstanding': _round2(
        todayBills.fold(0.0, (s, b) => s + (b.finalAmount - b.amountPaid).clamp(0, double.infinity)),
      ),
      'todayCustomersCount': todayBills.map((b) => b.customerId).toSet().length,
      'todayBillCount': todayBills.length,
      'todayAttendanceCount': todayAttendanceCount,
      'pendingDiscountRequests': pendingDiscountRequests,
      'lowStockItemCount': lowStockItemCount,
    };
  }

  /// Same shape as the bills-counting path above, assembled from one doc per
  /// day instead of one per bill.
  ///
  /// Every figure it returns is additive across days, which is why this works
  /// at all - except distinct clients, which is why each day's doc carries
  /// the set of customer ids it saw rather than a count.
  Future<Map<String, dynamic>> _summaryFromRollups({
    required DateTime queryStart,
    required DateTime todayStart,
    required DateTime weekStart,
    required DateTime monthStart,
    required int todayAttendanceCount,
    required int pendingDiscountRequests,
    required int lowStockItemCount,
  }) async {
    final snap = await db
        .collection('dailyStats')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart))
        .get();

    double sales(DateTime from) {
      var total = 0.0;
      for (final doc in snap.docs) {
        final day = _dayOf(doc);
        if (day == null || day.isBefore(from)) continue;
        total += _double(doc.data()['sales']);
      }
      return _round2(total);
    }

    Map<String, dynamic>? todayDoc;
    for (final doc in snap.docs) {
      final day = _dayOf(doc);
      if (day != null && !day.isBefore(todayStart)) todayDoc = doc.data();
    }
    final today = todayDoc ?? const <String, dynamic>{};

    return {
      'todaySales': sales(todayStart),
      'weekSales': sales(weekStart),
      'monthSales': sales(monthStart),
      'todayPaymentBreakdown': {
        'CASH': _round2(_double(today['collected_CASH'])),
        'CARD': _round2(_double(today['collected_CARD'])),
        'UPI': _round2(_double(today['collected_UPI'])),
      },
      // Clamped for the same reason the bills path clamps: a correction
      // could otherwise push the day negative.
      'todayOutstanding': _round2(_double(today['outstanding']).clamp(0, double.infinity)),
      'todayCustomersCount': (today['customerIds'] as List<dynamic>?)?.length ?? 0,
      'todayBillCount': (today['billCount'] as num?)?.toInt() ?? 0,
      'todayAttendanceCount': todayAttendanceCount,
      'pendingDiscountRequests': pendingDiscountRequests,
      'lowStockItemCount': lowStockItemCount,
    };
  }

  /// Bills raised from now on, as a live stream.
  ///
  /// Scoped to `createdAt > from` deliberately. A listener over the whole
  /// bills page would be delivered every one of those documents on attach -
  /// billed all over again, right after listBills() had just read them from
  /// cache - which would have made the app more expensive, not less. Bounded
  /// this way the opening snapshot is empty and the only documents it ever
  /// delivers are bills that did not exist when the app loaded.
  ///
  /// A range and an order on the same field need no composite index.
  Stream<List<FSBill>> watchBillsSince(DateTime from) {
    return db
        .collection('bills')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(from))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(FSBill.fromFirestore).toList());
  }

  /// Today's rollup document, as a live stream.
  ///
  /// The dashboard's figures all derive from these rollups, and every one of
  /// them that can move during a working day moves because today's document
  /// changed - a bill was raised, a payment was collected. Watching that one
  /// document is what makes the dashboard live, and it replaces the ~37
  /// rollup reads that used to follow every single bill.
  ///
  /// Only today's: the earlier days in the week and month window are settled
  /// history and cannot change while the app is open. Their totals are held
  /// as the difference between the aggregate and today, and today's new
  /// value is added back - see AppDataNotifier.
  Stream<Map<String, dynamic>> watchTodayStats() {
    final now = DateTime.now();
    return db
        .collection('dailyStats')
        .doc(dailyStatsDocId(DateTime(now.year, now.month, now.day)))
        .snapshots()
        .map((doc) {
      final d = doc.data() ?? const <String, dynamic>{};
      return {
        'todaySales': _round2(_double(d['sales'])),
        'todayPaymentBreakdown': {
          'CASH': _round2(_double(d['collected_CASH'])),
          'CARD': _round2(_double(d['collected_CARD'])),
          'UPI': _round2(_double(d['collected_UPI'])),
        },
        'todayOutstanding': _round2(_double(d['outstanding']).clamp(0, double.infinity)),
        'todayCustomersCount': (d['customerIds'] as List<dynamic>?)?.length ?? 0,
        'todayBillCount': (d['billCount'] as num?)?.toInt() ?? 0,
      };
    });
  }

  static DateTime? _dayOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final raw = doc.data()['date'];
    return raw is Timestamp ? raw.toDate() : null;
  }

  static double _double(dynamic v) => v is num ? v.toDouble() : 0.0;

  // --- Commissions ---

  /// Outstanding commission only - what someone is still owed.
  ///
  /// Filtered on status rather than taking the newest [limit] of everything,
  /// because a PAID record is never rendered anywhere: the only three things
  /// that read this list are AppData.pendingCommissionFor (which backs both
  /// the employee's Earnings screen and the owner's Payroll estimate) and
  /// the owner's two per-employee cards, and all three filter to PENDING
  /// before doing anything. The old query fetched a flat 1000 newest records
  /// and the app discarded every settled one - on an established salon that
  /// was most of them, on every single load.
  ///
  /// The limit stays as a ceiling, not a window: it now bounds how much is
  /// genuinely outstanding, which payroll drives back down, rather than how
  /// far back the history reaches.
  /// Falls back to the old unfiltered page if the status index isn't there.
  /// A composite index takes minutes to build after `firebase deploy`, and
  /// until it is ready the filtered query fails outright - so without this,
  /// shipping the code before the index finished would black out every
  /// owner's dashboard. Same defensive shape as listBillItemsForBills: the
  /// fallback just costs what this used to.
  Future<List<FSCommissionRecord>> listPendingCommissions({String? employeeId, int limit = 1000}) async {
    Query<Map<String, dynamic>> base = db.collection('commissionRecords');
    if (employeeId != null) base = base.where('employeeId', isEqualTo: employeeId);

    try {
      final snap = await base
          .where('status', isEqualTo: 'PENDING')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(FSCommissionRecord.fromFirestore).toList();
    } catch (e) {
      debugPrint('[Stylux] pending-commission index unavailable, reading the unfiltered page: $e');
      final snap = await base.orderBy('createdAt', descending: true).limit(limit).get();
      return snap.docs
          .map(FSCommissionRecord.fromFirestore)
          .where((c) => c.status == 'PENDING')
          .toList();
    }
  }

  Future<void> markCommissionPaid(String id) async {
    final ref = db.collection('commissionRecords').doc(id);
    if (!(await ref.get()).exists) throw Exception('Commission record not found');
    await ref.update({'status': 'PAID'});
  }

  // --- Discount requests ---

  /// How many discount requests are awaiting a decision.
  ///
  /// An owner used to load up to 300 request documents on every sign-in, and
  /// ten of the twelve places that read them only wanted this number - it is
  /// a badge on the dashboard, the bell, and four settings rows. A count()
  /// aggregation is billed as one read per thousand index entries, so this
  /// is one read instead of fifty.
  ///
  /// Deliberately no orderBy: a bare equality filter runs on the automatic
  /// single-field index, where adding a sort would need a composite one
  /// deployed to every salon before the badge worked anywhere.
  ///
  /// Staff are not covered by this. Their own requests are few, they are
  /// filtered to requestedBy already, and their Discounts tab needs the
  /// documents anyway - so they keep loading the list and derive the count
  /// from it.
  Future<int> countPendingDiscountRequests() async {
    try {
      final snap = await db
          .collection('discountRequests')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('[Stylux] pending discount count failed, badge will read 0: $e');
      return 0;
    }
  }

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
    return FSExpense(
      id: ref.id,
      title: expense.title,
      amount: expense.amount,
      category: expense.category,
      date: expense.date,
      notes: expense.notes,
    );
  }
}

/// Everything [SalonFirestore.createBill]'s transaction wrote.
///
/// All of it is composed client-side - the transaction allocates its own refs
/// and computes its own figures - so the caller can fold a bill into the
/// loaded snapshot without re-reading anything. That used to cost a full
/// commissionRecords page (1000 docs), the whole inventory collection and
/// every sales target on *every bill*, to learn values this object already
/// carries.
///
/// The one thing genuinely unknowable here is the bill's createdAt
/// ([FieldValue.serverTimestamp]), which is why the caller still re-reads
/// that single doc. Commission createdAt has the same problem but no caller
/// needs it to be exact, so it's approximated client-side (see
/// AppDataNotifier.createBill).
class FSCreatedBill {
  final FSBill bill;
  final List<FSBillItem> items;

  /// One per line, already carrying the id the transaction allocated.
  final List<FSCommissionRecord> commissions;

  /// inventoryItemId -> units taken out of stock by this bill.
  final Map<String, int> stockDeltas;

  /// Sales targets this bill moved, keyed by id and holding their new
  /// progress (and ACHIEVED status, where it tipped over).
  final Map<String, FSSalesTarget> updatedTargets;

  const FSCreatedBill({
    required this.bill,
    required this.items,
    required this.commissions,
    required this.stockDeltas,
    required this.updatedTargets,
  });
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
