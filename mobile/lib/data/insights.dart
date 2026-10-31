import 'models.dart';

/// Owner analytics: what Reports' insight cards show, and how bills are
/// rolled up so those cards cost almost no Firestore reads.
///
/// Two kinds of figure live here:
///  * rollups - running totals the bill transaction adds to
///    `dailyStats/{YYYY-MM-DD}` and `monthlyStats/{YYYY-MM}` (see
///    [billRollupFields]). Exact however many bills a salon has, and a
///    twelve-month report is ~13 document reads;
///  * snapshot figures - computed from what sign-in already loaded (clients,
///    stock, attendance, the newest bills). No reads at all.
///
/// Everything here is pure Dart (no Firestore), so it is unit-tested in
/// test/insights_test.dart.

double _r2(num n) => (n * 100).round() / 100;

String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);

/// [count] month starts ending with [now]'s month, oldest first.
List<DateTime> lastMonths(DateTime now, int count) =>
    [for (var i = count - 1; i >= 0; i--) DateTime(now.year, now.month - i, 1)];

// ---------------------------------------------------------------------------
// Rollups (write side)
// ---------------------------------------------------------------------------

/// One bill line, reduced to what the rollups need.
class RollupLine {
  final String type; // SERVICE | PRODUCT
  final String employeeId;
  /// unitPrice x quantity - the line's own discount. Before the bill-level
  /// discount and GST, which are tracked separately.
  final double net;
  final int quantity;
  /// Product cost price per unit at the time of the bill (0 for services).
  final double unitCost;
  /// Service category id; null for products or an uncategorised service.
  final String? categoryId;
  /// The service billed (null for products) - Reports' top services.
  final String? serviceId;
  final double commission;

  const RollupLine({
    required this.type,
    required this.employeeId,
    required this.net,
    this.quantity = 1,
    this.unitCost = 0,
    this.categoryId,
    this.serviceId,
    this.commission = 0,
  });
}

/// The amounts one bill adds to its day's and month's rollup docs, as flat
/// dotted keys (`byStaff.<uid>`) so the same result can be turned into
/// FieldValue.increment()s by the bill transaction and summed in memory by
/// the history backfill.
///
/// [monthly] adds the weekday x hour grid (Reports' busy-hours chart); the
/// daily doc gets a plain per-hour count instead. `sales` and `billCount`
/// are included for both - the caller drops them from the daily write,
/// which has always incremented those two itself.
Map<String, num> billRollupFields({
  required DateTime at,
  required double finalAmount,
  required double discount,
  required double tax,
  required String branchId,
  required List<RollupLine> lines,
  required bool firstVisit,
  required bool reminderReturn,
  required bool monthly,
}) {
  final out = <String, num>{};
  void add(String key, num v) {
    if (v == 0) return;
    out[key] = _r2((out[key] ?? 0) + v);
  }

  add('sales', finalAmount);
  add('billCount', 1);
  add('discount', discount);
  add('tax', tax);
  if (firstVisit) add('newClients', 1);
  if (reminderReturn) {
    add('reminderReturns', 1);
    add('reminderReturnSales', finalAmount);
  }
  if (branchId.isNotEmpty) add('byBranch.$branchId', finalAmount);

  final staffOnBill = <String>{};
  var hasProduct = false;
  for (final l in lines) {
    add('commission', l.commission);
    if (l.employeeId.isNotEmpty) {
      add('byStaff.${l.employeeId}', l.net);
      staffOnBill.add(l.employeeId);
    }
    if (l.type == 'PRODUCT') {
      hasProduct = true;
      add('productSales', l.net);
      add('productCost', l.unitCost * l.quantity);
      add('productUnits', l.quantity);
    } else {
      add('serviceSales', l.net);
      add('serviceCount', l.quantity);
      final cat = l.categoryId;
      add('byCategory.${cat == null || cat.isEmpty ? 'none' : cat}', l.net);
      // Month docs only: one key per service on the menu, which would bloat
      // thirty day docs for a figure Reports reads by the month.
      final sid = l.serviceId;
      if (monthly && sid != null && sid.isNotEmpty) {
        add('byService.$sid', l.net);
        add('serviceQty.$sid', l.quantity);
      }
    }
  }
  for (final id in staffOnBill) {
    add('staffBills.$id', 1);
  }
  if (hasProduct) add('billsWithProduct', 1);

  final hh = at.hour.toString().padLeft(2, '0');
  if (monthly) {
    add('slots.${at.weekday}_$hh', 1);
  } else {
    add('byHour.$hh', 1);
  }
  return out;
}

/// Turns flat dotted keys into nested maps (`{'byStaff': {'u1': 5}}`), with
/// [leaf] applied to every value - FieldValue.increment for a live write,
/// identity for the backfill.
Map<String, dynamic> nestRollupFields(Map<String, num> flat, dynamic Function(num) leaf) {
  final out = <String, dynamic>{};
  flat.forEach((key, value) {
    final dot = key.indexOf('.');
    if (dot < 0) {
      out[key] = leaf(value);
    } else {
      final group = out.putIfAbsent(key.substring(0, dot), () => <String, dynamic>{}) as Map<String, dynamic>;
      group[key.substring(dot + 1)] = leaf(value);
    }
  });
  return out;
}

/// Adds [b] into [a] (flat keys).
void addRollupFields(Map<String, num> a, Map<String, num> b) {
  b.forEach((k, v) => a[k] = _r2((a[k] ?? 0) + v));
}

/// Rollup totals for months before the live rollups started, worked out from
/// the bills themselves - Reports' one-time "fill in past months".
///
/// Only bills raised before [cutoff] (when the first live monthly rollup was
/// written) are counted, and the result goes in each month doc's separate
/// `pre` field, so a bill can never be counted twice and running it again
/// just rewrites the same numbers.
Map<String, Map<String, num>> backfillMonthlyRollups({
  required List<Bill> bills,
  required List<Customer> customers,
  required List<SalonService> services,
  required List<InventoryItem> inventory,
  required DateTime cutoff,
  required DateTime windowStart,
}) {
  final categoryOf = {for (final s in services) if (s.categoryId.isNotEmpty) s.id: s.categoryId};
  final costOf = {for (final i in inventory) i.id: i.costPrice};
  final createdAtOf = {for (final c in customers) c.id: c.createdAt};

  final inScope = bills
      .where((b) => b.createdAt != null && !b.createdAt!.isBefore(windowStart) && b.createdAt!.isBefore(cutoff))
      .toList()
    ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

  // First visit = the client's earliest bill here, for a client who joined
  // inside the window (anyone older had visits before it).
  final seen = <String>{};
  final out = <String, Map<String, num>>{};
  for (final b in inScope) {
    final joined = createdAtOf[b.customerId];
    final firstVisit = b.customerId.isNotEmpty &&
        seen.add(b.customerId) &&
        joined != null &&
        !joined.isBefore(windowStart);
    final fields = billRollupFields(
      at: b.createdAt!,
      finalAmount: b.finalAmount,
      discount: b.discountAmount,
      tax: b.taxAmount,
      branchId: b.branchId,
      firstVisit: firstVisit,
      reminderReturn: false,
      monthly: true,
      lines: [
        for (final i in b.items)
          RollupLine(
            type: i.type,
            employeeId: i.employeeId,
            net: i.unitPrice * i.quantity - i.discountAmount,
            quantity: i.quantity,
            unitCost: i.type == 'PRODUCT' ? (costOf[i.inventoryItemId] ?? 0) : 0,
            categoryId: i.type == 'SERVICE' ? categoryOf[i.serviceId] : null,
            serviceId: i.type == 'SERVICE' ? i.serviceId : null,
            commission: i.calculatedCommission,
          ),
      ],
    );
    addRollupFields(out.putIfAbsent(monthKey(b.createdAt!), () => {}), fields);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Rollups (read side)
// ---------------------------------------------------------------------------

/// A day's or month's rollup doc, flattened, with its live counters and its
/// backfilled `pre` part added together.
class RollupStats {
  final DateTime? period;
  final Map<String, double> _v;

  RollupStats._(this.period, this._v);

  static final empty = RollupStats._(null, const {});

  factory RollupStats.fromDoc(Map<String, dynamic> data, {DateTime? period}) {
    final v = <String, double>{};
    void absorb(Map<String, dynamic> m) {
      m.forEach((k, value) {
        if (value is num) {
          v[k] = (v[k] ?? 0) + value.toDouble();
        } else if (value is Map && k != 'pre') {
          value.forEach((sub, n) {
            if (n is num) v['$k.$sub'] = (v['$k.$sub'] ?? 0) + n.toDouble();
          });
        }
      });
    }

    absorb(data);
    final pre = data['pre'];
    if (pre is Map) absorb(Map<String, dynamic>.from(pre));
    return RollupStats._(period, v);
  }

  /// Several periods added together (a whole report window).
  factory RollupStats.sum(Iterable<RollupStats> all) {
    final v = <String, double>{};
    for (final s in all) {
      s._v.forEach((k, n) => v[k] = (v[k] ?? 0) + n);
    }
    return RollupStats._(null, v);
  }

  double operator [](String key) => _v[key] ?? 0;

  /// One nested group (`byStaff`, `byCategory`, ...) as id -> amount.
  Map<String, double> group(String name) {
    final prefix = '$name.';
    return {
      for (final e in _v.entries)
        if (e.key.startsWith(prefix)) e.key.substring(prefix.length): e.value,
    };
  }

  bool get hasData => this['billCount'] > 0 || this['sales'] > 0;

  double get sales => this['sales'];
  int get billCount => this['billCount'].round();
  double get discount => this['discount'];
  double get tax => this['tax'];
  double get serviceSales => this['serviceSales'];
  double get productSales => this['productSales'];
  double get productCost => this['productCost'];
  double get commission => this['commission'];
  int get newClients => this['newClients'].round();
  int get billsWithProduct => this['billsWithProduct'].round();
  int get reminderReturns => this['reminderReturns'].round();
  double get reminderReturnSales => this['reminderReturnSales'];

  /// Whether this period carries the line-level split (services vs
  /// products, staff, categories). Days and months before the rollups
  /// started only have `sales`/`billCount`.
  bool get hasBreakdown => serviceSales > 0 || productSales > 0;
}

// ---------------------------------------------------------------------------
// Snapshot figures (no reads)
// ---------------------------------------------------------------------------

/// How valuable the client base is: visit-frequency bands, top spenders and
/// spend per visit. From the denormalized customer totals, so it covers the
/// whole history, not just the loaded bills.
class ClientValue {
  final int oneVisit;
  final int twoToFour;
  final int fiveToNine;
  final int tenPlus;
  final int neverBilled;
  final double avgSpendPerVisit;
  final double avgLifetimeSpend;
  final List<Customer> topClients;

  const ClientValue({
    required this.oneVisit,
    required this.twoToFour,
    required this.fiveToNine,
    required this.tenPlus,
    required this.neverBilled,
    required this.avgSpendPerVisit,
    required this.avgLifetimeSpend,
    required this.topClients,
  });

  int get billedClients => oneVisit + twoToFour + fiveToNine + tenPlus;
}

ClientValue computeClientValue(List<Customer> customers, {int top = 5}) {
  var one = 0, few = 0, regular = 0, loyal = 0, never = 0;
  var spent = 0.0;
  var visits = 0;
  for (final c in customers) {
    final v = c.visitCount;
    if (v <= 0) {
      never++;
      continue;
    }
    spent += c.totalSpent;
    visits += v;
    if (v == 1) {
      one++;
    } else if (v <= 4) {
      few++;
    } else if (v <= 9) {
      regular++;
    } else {
      loyal++;
    }
  }
  final billed = one + few + regular + loyal;
  final ranked = customers.where((c) => c.totalSpent > 0).toList()
    ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
  return ClientValue(
    oneVisit: one,
    twoToFour: few,
    fiveToNine: regular,
    tenPlus: loyal,
    neverBilled: never,
    avgSpendPerVisit: visits == 0 ? 0 : _r2(spent / visits),
    avgLifetimeSpend: billed == 0 ? 0 : _r2(spent / billed),
    topClients: ranked.take(top).toList(),
  );
}

/// Clients who came in since [from]: first-timers vs people coming back.
class ClientMix {
  final int newClients;
  final int returning;
  const ClientMix(this.newClients, this.returning);
  int get total => newClients + returning;
}

ClientMix computeClientMix(List<Customer> customers, DateTime from) {
  var fresh = 0, back = 0;
  for (final c in customers) {
    final last = c.lastVisitAt;
    if (last == null || last.isBefore(from) || c.visitCount <= 0) continue;
    final joinedInWindow = c.createdAt != null && !c.createdAt!.isBefore(from);
    if (c.visitCount == 1 || joinedInWindow) {
      fresh++;
    } else {
      back++;
    }
  }
  return ClientMix(fresh, back);
}

/// How much of the client list WhatsApp messages and birthday wishes can
/// actually reach, and the gender split.
class ClientDetails {
  final int total;
  final int whatsappOptIn;
  final int withBirthday;
  final int withEmail;
  final int female;
  final int male;
  final int otherGender;
  final int unknownGender;

  const ClientDetails({
    required this.total,
    required this.whatsappOptIn,
    required this.withBirthday,
    required this.withEmail,
    required this.female,
    required this.male,
    required this.otherGender,
    required this.unknownGender,
  });
}

ClientDetails computeClientDetails(List<Customer> customers) {
  var wa = 0, bday = 0, email = 0, f = 0, m = 0, o = 0, u = 0;
  for (final c in customers) {
    if (c.whatsappOptIn) wa++;
    if ((c.birthday ?? '').isNotEmpty) bday++;
    if ((c.email ?? '').trim().isNotEmpty) email++;
    switch ((c.gender ?? '').toUpperCase()) {
      case 'FEMALE' || 'F':
        f++;
      case 'MALE' || 'M':
        m++;
      case '':
        u++;
      default:
        o++;
    }
  }
  return ClientDetails(
    total: customers.length,
    whatsappOptIn: wa,
    withBirthday: bday,
    withEmail: email,
    female: f,
    male: m,
    otherGender: o,
    unknownGender: u,
  );
}

/// Money owed, by how long it has been owed.
class DuesAging {
  final double days0to7;
  final double days8to30;
  final double days31to60;
  final double over60;
  /// Owed on bills older than the loaded page, so not dated - the
  /// difference between the clients' total balance and the bills above.
  final double undated;
  final int billsOwing;

  const DuesAging({
    required this.days0to7,
    required this.days8to30,
    required this.days31to60,
    required this.over60,
    required this.undated,
    required this.billsOwing,
  });

  double get total => days0to7 + days8to30 + days31to60 + over60 + undated;
}

DuesAging computeDuesAging(List<Bill> bills, List<Customer> customers, DateTime now) {
  var a = 0.0, b = 0.0, c = 0.0, d = 0.0;
  var owing = 0;
  for (final bill in bills) {
    final due = bill.amountDue;
    if (due <= 0.009 || bill.createdAt == null) continue;
    owing++;
    final age = now.difference(bill.createdAt!).inDays;
    if (age <= 7) {
      a += due;
    } else if (age <= 30) {
      b += due;
    } else if (age <= 60) {
      c += due;
    } else {
      d += due;
    }
  }
  final balance = customers.fold<double>(0, (s, x) => s + (x.outstandingBalance > 0 ? x.outstandingBalance : 0));
  final dated = a + b + c + d;
  return DuesAging(
    days0to7: _r2(a),
    days8to30: _r2(b),
    days31to60: _r2(c),
    over60: _r2(d),
    undated: _r2(balance > dated ? balance - dated : 0),
    billsOwing: owing,
  );
}

/// One product's stock health.
class ProductStock {
  final InventoryItem item;
  final int unitsSold;
  /// Days of stock left at the recent selling rate; null when it hasn't
  /// sold in the period looked at.
  final double? daysLeft;
  double get marginPct => item.price <= 0 ? 0 : (item.price - item.costPrice) / item.price * 100;
  double get valueAtCost => item.costPrice * item.stockCount;

  const ProductStock({required this.item, required this.unitsSold, required this.daysLeft});
}

class StockInsights {
  final double valueAtCost;
  final double valueAtPrice;
  final List<ProductStock> products;
  /// How many days of bills the selling rates are based on (the loaded bills
  /// may cover less than the 30 days asked for).
  final int daysCovered;

  const StockInsights({
    required this.valueAtCost,
    required this.valueAtPrice,
    required this.products,
    required this.daysCovered,
  });

  double get potentialProfit => valueAtPrice - valueAtCost;

  /// In stock but not sold at all in the period - money sitting on a shelf.
  /// Only meaningful once the period is long enough to judge.
  List<ProductStock> get notSelling =>
      daysCovered < 14 ? const [] : products.where((p) => p.item.stockCount > 0 && p.unitsSold == 0).toList();

  /// Will run out within two weeks at the current rate.
  List<ProductStock> get runningOut =>
      products.where((p) => p.daysLeft != null && p.daysLeft! <= 14).toList()
        ..sort((a, b) => a.daysLeft!.compareTo(b.daysLeft!));
}

StockInsights computeStockInsights(List<InventoryItem> inventory, List<Bill> bills, DateTime now, {int days = 30}) {
  final from = now.subtract(Duration(days: days));
  final dated = bills.where((b) => b.createdAt != null).toList();
  // The loaded page may not reach back [days]; rates use what it covers.
  var covered = days;
  if (dated.isNotEmpty) {
    final oldest = dated.map((b) => b.createdAt!).reduce((a, b) => a.isBefore(b) ? a : b);
    if (oldest.isAfter(from)) covered = now.difference(oldest).inDays.clamp(1, days);
  } else {
    covered = 0;
  }

  final sold = <String, int>{};
  for (final b in dated) {
    if (b.createdAt!.isBefore(from)) continue;
    for (final i in b.items) {
      if (i.type != 'PRODUCT' || i.inventoryItemId == null) continue;
      sold[i.inventoryItemId!] = (sold[i.inventoryItemId!] ?? 0) + i.quantity;
    }
  }

  var cost = 0.0, price = 0.0;
  final products = <ProductStock>[];
  for (final item in inventory) {
    final stock = item.stockCount < 0 ? 0 : item.stockCount;
    cost += item.costPrice * stock;
    price += item.price * stock;
    final units = sold[item.id] ?? 0;
    final perDay = covered > 0 ? units / covered : 0;
    products.add(ProductStock(
      item: item,
      unitsSold: units,
      daysLeft: perDay > 0 ? stock / perDay : null,
    ));
  }
  products.sort((a, b) => b.valueAtCost.compareTo(a.valueAtCost));
  return StockInsights(
    valueAtCost: _r2(cost),
    valueAtPrice: _r2(price),
    products: products,
    daysCovered: covered,
  );
}

/// One team member's month: takings from the rollups, hours from attendance.
class StaffMonth {
  final EmployeeProfile employee;
  final double sales;
  final int billsServed;
  final double hoursOnShift;
  final int daysPresent;
  final int lateDays;

  const StaffMonth({
    required this.employee,
    required this.sales,
    required this.billsServed,
    required this.hoursOnShift,
    required this.daysPresent,
    required this.lateDays,
  });

  double get avgBill => billsServed == 0 ? 0 : sales / billsServed;
  double? get salesPerHour => hoursOnShift < 1 ? null : sales / hoursOnShift;
}

List<StaffMonth> computeStaffMonth({
  required List<EmployeeProfile> employees,
  required List<AttendanceRecord> attendance,
  required RollupStats month,
  required DateTime monthStartDate,
}) {
  final next = DateTime(monthStartDate.year, monthStartDate.month + 1, 1);
  final sales = month.group('byStaff');
  final served = month.group('staffBills');
  final out = <StaffMonth>[];
  for (final e in employees) {
    var hours = 0.0;
    var present = 0, late = 0;
    for (final a in attendance) {
      if (a.employeeId != e.id || a.date == null) continue;
      if (a.date!.isBefore(monthStartDate) || !a.date!.isBefore(next)) continue;
      if (a.status == 'PRESENT' || a.status == 'LATE') present++;
      if (a.status == 'LATE') late++;
      final inAt = a.clockIn, outAt = a.clockOut;
      if (inAt != null && outAt != null && outAt.isAfter(inAt)) {
        final len = outAt.difference(inAt);
        // A forgotten clock-out closed days later is not a real shift.
        if (len.inHours < 16) hours += len.inMinutes / 60;
      }
    }
    final s = sales[e.id] ?? 0;
    if (!e.active && s == 0 && present == 0) continue;
    out.add(StaffMonth(
      employee: e,
      sales: _r2(s),
      billsServed: (served[e.id] ?? 0).round(),
      hoursOnShift: _r2(hours),
      daysPresent: present,
      lateDays: late,
    ));
  }
  out.sort((a, b) => b.sales.compareTo(a.sales));
  return out;
}

/// One month's profit and loss.
class MonthPnl {
  final DateTime month;
  /// Takings without GST - the tax is the government's, not the salon's.
  final double revenue;
  final double productCost;
  final double expenses;
  /// Salary slips for the month; when payroll hasn't been run for it yet,
  /// the commission earned so far stands in and [payrollEstimated] is set.
  final double payroll;
  final bool payrollEstimated;

  const MonthPnl({
    required this.month,
    required this.revenue,
    required this.productCost,
    required this.expenses,
    required this.payroll,
    required this.payrollEstimated,
  });

  double get profit => revenue - productCost - expenses - payroll;
  double get marginPct => revenue <= 0 ? 0 : profit / revenue * 100;
}

List<MonthPnl> computePnl({
  required List<DateTime> months,
  required Map<String, RollupStats> rollups,
  required List<Expense> expenses,
  required List<SalaryRecord> salaries,
}) {
  return [
    for (final m in months)
      () {
        final r = rollups[monthKey(m)] ?? RollupStats.empty;
        final spent = expenses
            .where((e) => e.date != null && e.date!.year == m.year && e.date!.month == m.month)
            .fold<double>(0, (s, e) => s + e.amount);
        final slips = salaries.where((s) => s.year == m.year && s.month == m.month).toList();
        final paid = slips.fold<double>(0, (s, x) => s + x.totalPaid);
        return MonthPnl(
          month: m,
          revenue: _r2(r.sales - r.tax),
          productCost: _r2(r.productCost),
          expenses: _r2(spent),
          payroll: _r2(slips.isEmpty ? r.commission : paid),
          payrollEstimated: slips.isEmpty,
        );
      }(),
  ];
}
