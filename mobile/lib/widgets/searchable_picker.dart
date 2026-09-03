import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme.dart';

/// Opens a search-as-you-type bottom sheet over [items] and resolves with
/// the tapped item (or null if dismissed). Used in place of a plain
/// `DropdownButtonFormField` for lists that can grow large (customers,
/// employees) - a native dropdown forces scrolling through every record
/// with no way to filter, which gets unusable past a handful of entries
/// and is worse still on a small touchscreen.
Future<T?> showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) labelOf,
  String Function(T)? subtitleOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _SearchablePickerSheet<T>(title: title, items: items, labelOf: labelOf, subtitleOf: subtitleOf),
  );
}

class _SearchablePickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;

  const _SearchablePickerSheet({required this.title, required this.items, required this.labelOf, this.subtitleOf});

  @override
  State<_SearchablePickerSheet<T>> createState() => _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T> extends State<_SearchablePickerSheet<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase().trim();
    final filtered = query.isEmpty
        ? widget.items
        : widget.items.where((item) {
            final label = widget.labelOf(item).toLowerCase();
            final subtitle = widget.subtitleOf?.call(item).toLowerCase() ?? '';
            return label.contains(query) || subtitle.contains(query);
          }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
                    ),
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.x, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (val) => setState(() => _query = val),
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matches found.', style: TextStyle(color: AppTheme.slateLight)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final subtitle = widget.subtitleOf?.call(item);
                          return ListTile(
                            title: Text(widget.labelOf(item), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(color: AppTheme.slateLight, fontSize: 12)),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
