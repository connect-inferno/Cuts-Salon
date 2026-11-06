import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../data/money.dart';
import '../../../data/service_menu.dart';
import '../../../theme.dart';
import '../../../widgets/app_page_header.dart';
import 'owner_billing_inventory_expenses_tab.dart' show showAddServiceDialog;

const String _popular = '__popular';
const String _products = '__products';

/// Gents / Ladies / both as one segmented row. [options] pairs each stored
/// value with its label: the pick screen calls null "All", the forms "Both".
class AudienceChoice extends StatelessWidget {
  final String? value;
  final List<(String?, String)> options;
  final ValueChanged<String?> onChanged;

  const AudienceChoice({super.key, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final (option, label) in options)
            Expanded(
              child: Semantics(
                selected: option == value,
                button: true,
                child: InkWell(
                  onTap: () => onChanged(option),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: option == value ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: option == value ? AppTheme.borderSubtle : Colors.transparent),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: option == value ? AppTheme.primaryBlue : AppTheme.slateLight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MenuRailEntry {
  final String id;
  final String label;
  /// Shown as a small badge when above zero.
  final int count;
  /// The badge is a warning (low stock), not a tally of what's been picked.
  final bool warning;

  const MenuRailEntry(this.id, this.label, {this.count = 0, this.warning = false});
}

/// The list of categories down the left of the Add services and Services
/// screens. The same on both, so finding something works the same way.
class MenuRail extends StatelessWidget {
  final List<MenuRailEntry> entries;
  final String selected;
  final ValueChanged<String> onSelected;

  const MenuRail({super.key, required this.entries, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bgSurface,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          final isSelected = entry.id == selected;
          return Semantics(
            selected: isSelected,
            button: true,
            child: InkWell(
              onTap: () => onSelected(entry.id),
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : null,
                  border: Border(
                    left: BorderSide(color: isSelected ? AppTheme.primaryBlue : Colors.transparent, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.label,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.primaryBlue : AppTheme.slateMedium,
                        ),
                      ),
                    ),
                    if (entry.count > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: entry.warning ? AppTheme.accentAmber : AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${entry.count}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Settles a price-varies service's price for this bill: one of its usual
/// prices, or any amount typed. Null means they backed out.
Future<double?> askServicePrice(BuildContext context, SalonService svc) {
  final controller = TextEditingController();
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      void done() {
        final value = double.tryParse(controller.text.trim()) ?? 0;
        if (value > 0) Navigator.pop(ctx, value);
      }

      return AlertDialog(
        // With its category: "O3+" alone doesn't say which O3+.
        title: Text(svc.categoryName == null ? svc.name : '${svc.name} (${svc.categoryName})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (svc.priceOptions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in svc.priceOptions)
                    ActionChip(
                      label: Text(formatInr(option)),
                      onPressed: () => Navigator.pop(ctx, option),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: controller,
              autofocus: svc.priceOptions.isEmpty,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => done(),
              decoration: const InputDecoration(labelText: 'Price for this client (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: done, child: const Text('Add')),
        ],
      );
    },
  );
}

/// Where a bill's services are picked: categories down the left, one
/// category's services on the right, like the food and grocery apps staff
/// already use. New Bill stays one short screen because the menu lives here.
///
/// It edits New Bill's own collections and calls [onChanged], so leaving by
/// Done or by the back arrow both keep what was picked.
class ServicePickerPage extends ConsumerStatefulWidget {
  final String? clientName;
  final String? audience;
  final ValueChanged<String?> onAudienceChanged;
  final Set<String> services;
  final Map<String, double> prices;
  final Map<String, int> products;
  final VoidCallback onChanged;

  const ServicePickerPage({
    super.key,
    required this.clientName,
    required this.audience,
    required this.onAudienceChanged,
    required this.services,
    required this.prices,
    required this.products,
    required this.onChanged,
  });

  @override
  ConsumerState<ServicePickerPage> createState() => _ServicePickerPageState();
}

class _ServicePickerPageState extends ConsumerState<ServicePickerPage> {
  final _search = TextEditingController();
  late String? _audience = widget.audience;
  String? _entry;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  Future<void> _toggle(SalonService svc) async {
    if (widget.services.contains(svc.id)) {
      widget.services.remove(svc.id);
      widget.prices.remove(svc.id);
    } else {
      if (svc.priceVaries) {
        final price = await askServicePrice(context, svc);
        if (price == null || !mounted) return;
        widget.prices[svc.id] = price;
      }
      widget.services.add(svc.id);
    }
    _changed();
  }

  void _setQuantity(InventoryItem item, int quantity) {
    if (quantity <= 0) {
      widget.products.remove(item.id);
    } else {
      widget.products[item.id] = quantity;
    }
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appDataProvider).valueOrNull;
    if (state == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final query = _search.text.trim().toLowerCase();
    final shown = state.services.where((s) => audiencesOverlap(s.audience, _audience)).toList();
    final groups = groupServices(shown);
    final popular = popularServices(state.bills, shown);

    // Products sit near the top: below every category they were out of sight.
    final entries = [
      if (popular.isNotEmpty) _popular,
      if (state.inventory.isNotEmpty) _products,
      for (final g in groups) g.name,
    ];
    // Opens on services even when Products is first: that's what most bills
    // are for.
    final opening = entries.where((e) => e != _products).firstOrNull ?? entries.firstOrNull;
    final current = entries.contains(_entry) ? _entry : opening;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: 'Add services',
            subtitle: widget.clientName,
            leading: AppPageLeading.back,
            actions: [
              AppPageAction(
                icon: PhosphorIconsBold.plus,
                label: 'New',
                tooltip: 'Add a new service to the menu',
                onTap: () => showAddServiceDialog(context, ref, state.categories, audience: _audience),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AudienceChoice(
                  value: _audience,
                  options: const [(null, 'All'), (kAudienceGents, 'Gents'), (kAudienceLadies, 'Ladies')],
                  onChanged: (audience) {
                    setState(() => _audience = audience);
                    widget.onAudienceChanged(audience);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search services and products',
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(PhosphorIconsRegular.x, size: 16),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          Expanded(
            child: query.isNotEmpty
                ? _buildSearchResults(state, shown, query)
                : entries.isEmpty
                    ? const _Empty('Nothing on this side of the menu yet.')
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 116,
                            child: MenuRail(
                              entries: _railEntries(entries, groups),
                              selected: current!,
                              onSelected: (entry) => setState(() => _entry = entry),
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1, color: AppTheme.borderSubtle),
                          Expanded(child: _buildList(state, current, groups, popular)),
                        ],
                      ),
          ),
          _buildDock(state),
        ],
      ),
    );
  }

  List<MenuRailEntry> _railEntries(List<String> entries, List<ServiceGroup> groups) {
    int picked(String entry) {
      if (entry == _popular) return 0;
      if (entry == _products) return widget.products.length;
      return groups
          .firstWhere((g) => g.name == entry)
          .services
          .where((s) => widget.services.contains(s.id))
          .length;
    }

    return [
      for (final entry in entries)
        MenuRailEntry(
          entry,
          switch (entry) {
            _popular => 'Popular',
            _products => 'Products',
            _ => entry,
          },
          count: picked(entry),
        ),
    ];
  }

  Widget _buildList(AppData state, String current, List<ServiceGroup> groups, List<SalonService> popular) {
    if (current == _products) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          const _Title('Products'),
          for (final item in state.inventory) _productRow(item),
        ],
      );
    }
    final isPopular = current == _popular;
    final services = isPopular ? popular : groups.firstWhere((g) => g.name == current).services;
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        _Title(isPopular ? 'Most billed' : current),
        for (final svc in services) _serviceRow(svc, showCategory: isPopular),
      ],
    );
  }

  Widget _buildSearchResults(AppData state, List<SalonService> shown, String query) {
    final services = shown
        .where((s) => s.name.toLowerCase().contains(query) || (s.categoryName?.toLowerCase().contains(query) ?? false))
        .toList();
    final products = state.inventory.where((p) => p.name.toLowerCase().contains(query)).toList();
    if (services.isEmpty && products.isEmpty) {
      return _Empty('Nothing matches "${_search.text.trim()}"');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        for (final svc in services) _serviceRow(svc, showCategory: true),
        for (final item in products) _productRow(item),
      ],
    );
  }

  Widget _serviceRow(SalonService svc, {required bool showCategory}) {
    final picked = widget.services.contains(svc.id);
    final detail = [
      if (showCategory && svc.categoryName != null) svc.categoryName!,
      if (svc.audience != null && _audience == null) serviceAudienceLabel(svc.audience),
    ].join(' • ');
    final price = widget.prices.containsKey(svc.id) ? formatInr(widget.prices[svc.id]!) : servicePriceLabel(svc);

    return Semantics(
      checked: picked,
      button: true,
      child: InkWell(
        onTap: () => _toggle(svc),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: picked ? AppTheme.primaryLight : null,
            border: const Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      svc.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slateMedium,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(detail, style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: picked ? AppTheme.primaryBlue : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  picked ? PhosphorIconsBold.check : PhosphorIconsBold.plus,
                  size: 16,
                  color: picked ? Colors.white : AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productRow(InventoryItem item) {
    final quantity = widget.products[item.id] ?? 0;
    final low = item.stockCount <= 5;
    Widget step(IconData icon, String tip, VoidCallback? onTap) => Tooltip(
          message: tip,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(icon, size: 14, color: onTap == null ? AppTheme.borderStrong : AppTheme.primaryBlue),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: quantity > 0 ? AppTheme.primaryLight : null,
        border: const Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
                const SizedBox(height: 2),
                Text(
                  '${formatInr(item.price)} • ${item.stockCount} ${low ? 'left' : 'in stock'}',
                  style: TextStyle(fontSize: 12, color: low ? AppTheme.accentAmber : AppTheme.slateLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (quantity == 0)
            InkWell(
              onTap: item.stockCount > 0 ? () => _setQuantity(item, 1) : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  PhosphorIconsBold.plus,
                  size: 16,
                  color: item.stockCount > 0 ? AppTheme.primaryBlue : AppTheme.borderStrong,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primarySoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  step(PhosphorIconsBold.minus, 'Less', () => _setQuantity(item, quantity - 1)),
                  Text('$quantity', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
                  step(PhosphorIconsBold.plus, 'More',
                      quantity >= item.stockCount ? null : () => _setQuantity(item, quantity + 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDock(AppData state) {
    var total = 0.0;
    for (final s in state.services.where((s) => widget.services.contains(s.id))) {
      total += widget.prices[s.id] ?? s.price;
    }
    for (final p in state.inventory) {
      total += p.price * (widget.products[p.id] ?? 0);
    }
    final count = widget.services.length + widget.products.length;

    return Container(
      color: AppTheme.primaryBlue,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count == 0 ? 'Nothing added yet' : '$count item${count == 1 ? '' : 's'} added',
                      style: const TextStyle(fontSize: 12, color: AppTheme.primarySoft),
                    ),
                    Text(
                      formatInr(total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryBlue,
                  minimumSize: const Size(96, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.slateLight)),
    );
  }
}
