import 'client_package.dart';
import 'models.dart';
import 'money.dart';

/// Who a service is for, as stored on services/{id}.audience. A service with
/// no audience is for both, which is also what every service saved before
/// this field existed reads as.
const String kAudienceGents = 'GENTS';
const String kAudienceLadies = 'LADIES';

String serviceAudienceLabel(String? audience) => switch (audience) {
      kAudienceGents => 'Gents',
      kAudienceLadies => 'Ladies',
      _ => 'Gents and Ladies',
    };

/// The tab a client's bill opens on. Clients with no gender on file keep
/// whichever tab is showing.
String? audienceForGender(String? gender) => switch ((gender ?? '').toUpperCase()) {
      'MALE' || 'M' => kAudienceGents,
      'FEMALE' || 'F' => kAudienceLadies,
      _ => null,
    };

/// True when two services could be offered to the same client.
bool audiencesOverlap(String? a, String? b) => a == null || b == null || a == b;

class MenuCategory {
  final String name;
  final bool gents;
  final bool ladies;

  const MenuCategory(this.name, {this.gents = true, this.ladies = true});
}

/// The categories of a salon's printed menu, hair first and body last, in the
/// order Billing shows them. A salon can add its own on top of these.
const List<MenuCategory> kServiceMenu = [
  MenuCategory('Cut with Wash', ladies: false),
  MenuCategory('Basic Cut with Wash', gents: false),
  MenuCategory('Advance Cut', gents: false),
  MenuCategory('Kids', ladies: false),
  MenuCategory('Baby Cutting', gents: false),
  MenuCategory('Wash + Hair Set', ladies: false),
  MenuCategory('Hair Wash', gents: false),
  MenuCategory('Hair Styling', gents: false),
  MenuCategory('Shaving', ladies: false),
  MenuCategory('Highlights'),
  MenuCategory('Loreal Colour with Wash', ladies: false),
  MenuCategory('Matrix Colour with Wash', ladies: false),
  MenuCategory('Loreal Global Colour', gents: false),
  MenuCategory('Matrix Global Colour', gents: false),
  MenuCategory('Loreal Colour', gents: false),
  MenuCategory('Matrix Colour', gents: false),
  MenuCategory('Hair Spa'),
  MenuCategory('Head Massage + Steam', ladies: false),
  MenuCategory('Head Massage', gents: false),
  MenuCategory('Hair Treatment', ladies: false),
  MenuCategory('Medium Hair Treatment', gents: false),
  MenuCategory('Long Hair Treatment', gents: false),
  MenuCategory('Clean Up'),
  MenuCategory('Hydra Clean Up'),
  MenuCategory('Bleach'),
  MenuCategory('D-Tan'),
  MenuCategory('Face Massage'),
  MenuCategory('Facial'),
  MenuCategory('Hydra Facial'),
  MenuCategory('Body Treatment'),
  MenuCategory('Reflexology'),
  MenuCategory('Manicure'),
  MenuCategory('Pedicure'),
  MenuCategory('Threading', gents: false),
  MenuCategory('Regular Waxing', gents: false),
  MenuCategory('Brazilian Wax (Stripless)', gents: false),
  MenuCategory('Flavoured Waxing / Tan Remover', gents: false),
];

/// What the Add and Edit Service forms offer: the menu's categories for
/// [audience], then any of the salon's own that the menu doesn't have.
List<String> serviceCategoryChoices(String? audience, Iterable<String> salonCategories) {
  final menu = [
    for (final c in kServiceMenu)
      if (audience == null || (audience == kAudienceGents ? c.gents : c.ladies)) c.name,
  ];
  final known = {for (final c in kServiceMenu) c.name.toLowerCase()};
  final own = <String>{
    for (final name in salonCategories)
      if (name.trim().isNotEmpty && !known.contains(name.toLowerCase())) name,
  }.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [...menu, ...own];
}

class ServiceGroup {
  final String name;
  final List<SalonService> services;

  const ServiceGroup(this.name, this.services);
}

/// The heading for services with no category of their own.
const String kUncategorised = 'Other';

/// [services] under their categories: menu order first, then the salon's own
/// categories by name, then anything with no category at all. By name inside
/// each one, since Firestore hands them back in no useful order.
List<ServiceGroup> groupServices(Iterable<SalonService> services) {
  final byName = <String, List<SalonService>>{};
  for (final s in services) {
    final name = (s.categoryName ?? '').trim();
    byName.putIfAbsent(name.isEmpty ? kUncategorised : name, () => []).add(s);
  }
  final order = {for (final (i, c) in kServiceMenu.indexed) c.name.toLowerCase(): i};
  int rank(String name) {
    if (name == kUncategorised) return kServiceMenu.length + 1;
    return order[name.toLowerCase()] ?? kServiceMenu.length;
  }

  final names = byName.keys.toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.toLowerCase().compareTo(b.toLowerCase());
    });
  return [
    for (final name in names)
      ServiceGroup(name, byName[name]!..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()))),
  ];
}

/// The services billed most often in [bills], for the top of the pick screen.
/// Worked out from the bills sign-in already loaded, so it costs no read, and
/// a new salon simply has none yet.
List<SalonService> popularServices(Iterable<Bill> bills, Iterable<SalonService> services, {int limit = 8}) {
  final counts = <String, int>{};
  for (final bill in bills) {
    for (final item in bill.items) {
      final id = item.serviceId;
      if (id != null) counts[id] = (counts[id] ?? 0) + item.quantity;
    }
  }
  return services.where((s) => counts.containsKey(s.id)).toList()
    ..sort((a, b) {
      final byCount = counts[b.id]!.compareTo(counts[a.id]!);
      return byCount != 0 ? byCount : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    })
    ..length = counts.keys.where((id) => services.any((s) => s.id == id)).length.clamp(0, limit);
}

/// The name a bill line and Reports show. The menu repeats names across
/// categories ("Regular" is a clean up, a manicure and a pedicure), so a
/// shared name carries its category or the invoice wouldn't say which it was.
String billLineName(SalonService service, Iterable<SalonService> all) {
  final category = (service.categoryName ?? '').trim();
  if (category.isEmpty) return service.name;
  final shared = all.any((s) =>
      s.id != service.id &&
      s.name.toLowerCase() == service.name.toLowerCase() &&
      (s.categoryName ?? '').toLowerCase() != category.toLowerCase());
  return shared ? '${service.name} ($category)' : service.name;
}

/// A service's price as a list shows it. One that varies has no single price
/// to quote, so it says the range, or that it depends.
String servicePriceLabel(SalonService service) {
  if (!service.priceVaries) return formatInr(service.price);
  final options = service.priceOptions;
  if (options.isEmpty) return service.price > 0 ? 'From ${formatInr(service.price)}' : 'On consultation';
  if (options.length == 1) return formatInr(options.first);
  return '${formatInr(options.reduce((a, b) => a < b ? a : b))} - ${formatInr(options.reduce((a, b) => a > b ? a : b))}';
}

/// "2900, 3400, 3900" as a form types it: sorted, without repeats. Anything
/// that isn't a positive number is left out.
List<double> parsePriceOptions(String raw) {
  final values = <double>{
    for (final part in raw.split(RegExp(r'[,/\s]+')))
      if ((double.tryParse(part) ?? 0) > 0) double.parse(part),
  }.toList()
    ..sort();
  return values;
}

/// The ready-made menu file for a salon, for salons that have one. Bundled
/// because a menu is owned by the salon that printed it, not shared.
const Map<String, String> kSalonMenuAssets = {
  'cuts-salon': 'assets/menus/cuts.json',
  'test-salon-ee06a': 'assets/menus/cuts.json',
};

class MenuEntry {
  final String category;
  final String name;
  final String? audience;
  final double price;
  final bool priceVaries;
  final List<double> priceOptions;

  const MenuEntry({
    required this.category,
    required this.name,
    required this.price,
    this.audience,
    this.priceVaries = false,
    this.priceOptions = const [],
  });

  factory MenuEntry.fromMap(Map<String, dynamic> m) => MenuEntry(
        category: m['category'] as String,
        name: m['name'] as String,
        audience: m['audience'] as String?,
        price: (m['price'] as num).toDouble(),
        priceVaries: m['priceVaries'] as bool? ?? false,
        priceOptions: [for (final o in m['priceOptions'] as List? ?? const []) (o as num).toDouble()],
      );
}

class SalonMenu {
  final List<MenuEntry> services;
  final List<PackagePlan> packagePlans;

  const SalonMenu({required this.services, this.packagePlans = const []});

  factory SalonMenu.fromMap(Map<String, dynamic> m) => SalonMenu(
        services: [for (final s in m['services'] as List) MenuEntry.fromMap(s as Map<String, dynamic>)],
        packagePlans: [
          for (final p in m['packagePlans'] as List? ?? const []) PackagePlan.fromMap(p as Map<String, dynamic>),
        ],
      );
}

/// The entries a salon doesn't have yet, by the same test the Add Service form
/// uses. Loading a menu twice therefore adds nothing the second time.
List<MenuEntry> menuEntriesToAdd(Iterable<MenuEntry> entries, Iterable<SalonService> existing) {
  bool same(MenuEntry e, SalonService s) =>
      s.name.toLowerCase() == e.name.toLowerCase() &&
      (s.categoryName ?? '').toLowerCase() == e.category.toLowerCase() &&
      audiencesOverlap(s.audience, e.audience);
  return [
    for (final e in entries)
      if (!existing.any((s) => same(e, s))) e,
  ];
}
