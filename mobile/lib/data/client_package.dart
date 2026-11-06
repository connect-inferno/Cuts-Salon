/// Prepaid packages: "pay ₹5,000, get services worth ₹6,000 for 6 months".
///
/// A package is credit held for one client. Selling one is money in
/// (dailyStats.collected_*) with nothing billed; spending it is a bill with no
/// new money. So takings still mean work done and Collected still means money
/// received, and neither counts a package twice.
///
/// Pure Dart, unit-tested in test/client_package_test.dart.
library;

double _r2(num n) => (n * 100).round() / 100;

/// One offer on the salon's list, stored in settings/main.packagePlans.
class PackagePlan {
  final double pay;
  final double worth;
  final int months;

  const PackagePlan({required this.pay, required this.worth, required this.months});

  factory PackagePlan.fromMap(Map<String, dynamic> m) => PackagePlan(
        pay: (m['pay'] as num?)?.toDouble() ?? 0,
        worth: (m['worth'] as num?)?.toDouble() ?? 0,
        months: (m['months'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {'pay': pay, 'worth': worth, 'months': months};

  /// The reason a plan can't be saved, or null. A plan worth less than it
  /// costs would lose the client money; the rules refuse one too.
  String? get problem {
    if (pay <= 0) return 'Enter what the client pays';
    if (worth < pay) return 'It must be worth at least what the client pays';
    if (months < 1 || months > 60) return 'Validity must be 1 to 60 months';
    return null;
  }
}

/// One package a client has bought. Held by customerId alone, with no copy of
/// the client's name, so erasing a client has nothing to clean up here.
class ClientPackage {
  final String id;
  final String customerId;
  final double paidAmount;
  final double creditValue;
  final double balance;
  final String paymentMethod;
  final DateTime? soldAt;
  final DateTime expiresAt;

  const ClientPackage({
    required this.id,
    required this.customerId,
    required this.paidAmount,
    required this.creditValue,
    required this.balance,
    required this.paymentMethod,
    required this.expiresAt,
    this.soldAt,
  });

  bool isUsableAt(DateTime now) => balance > 0.009 && now.isBefore(expiresAt);

  ClientPackage withBalance(double value) => ClientPackage(
        id: id,
        customerId: customerId,
        paidAmount: paidAmount,
        creditValue: creditValue,
        balance: value,
        paymentMethod: paymentMethod,
        soldAt: soldAt,
        expiresAt: expiresAt,
      );

  /// The part of each rupee of credit the client didn't pay for: 1/6 on
  /// "pay 5,000, get 6,000".
  double get bonusRate => creditValue <= 0 ? 0 : 1 - paidAmount / creditValue;
}

/// [client]'s usable packages, the one expiring soonest first, so credit that
/// would lapse is spent before credit that wouldn't.
List<ClientPackage> usablePackages(Iterable<ClientPackage> all, String? client, DateTime now) {
  return all.where((p) => p.customerId == client && p.isUsableAt(now)).toList()
    ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
}

double usableCredit(Iterable<ClientPackage> all, String? client, DateTime now) =>
    _r2(usablePackages(all, client, now).fold(0.0, (sum, p) => sum + p.balance));

/// How [amount] comes out of [packages], in order: package id -> credit taken.
/// Takes what's there, so the caller must check the total covers [amount].
Map<String, double> drawFromPackages(Iterable<ClientPackage> packages, double amount) {
  final draws = <String, double>{};
  var left = amount;
  for (final p in packages) {
    if (left <= 0.009) break;
    final take = _r2(p.balance < left ? p.balance : left);
    if (take <= 0) continue;
    draws[p.id] = take;
    left = _r2(left - take);
  }
  return draws;
}

/// The part of [draws] the salon never received money for. Takings count a
/// package bill at full price, so the profit report takes this back off.
double packageBonusOf(Map<String, double> draws, Iterable<ClientPackage> packages) {
  final byId = {for (final p in packages) p.id: p};
  var bonus = 0.0;
  draws.forEach((id, amount) => bonus += amount * (byId[id]?.bonusRate ?? 0));
  return _r2(bonus);
}

/// [from] plus [months], landing on the last day of a shorter month rather
/// than spilling into the next: one month from 31 January is 28 February.
DateTime addMonths(DateTime from, int months) {
  final first = DateTime(from.year, from.month + months, 1);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  final day = from.day < lastDay ? from.day : lastDay;
  return DateTime(first.year, first.month, day, from.hour, from.minute, from.second);
}
