import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data_provider.dart';
import '../../../data/birthday.dart';
import '../../../data/models.dart';
import '../../../theme.dart';
import '../../../widgets/async_state_views.dart';
import '../../../widgets/ds.dart';
import '../../../widgets/open_link.dart';
import 'owner_customers_employees_tab.dart' show showClientBirthdayDialog;

/// Clients' birthdays, opened from the Birthdays card on Clients.
///
/// Today, the rest of this week and the next month, each with a one-tap
/// WhatsApp wish and a call, plus the clients with no birthday saved so the
/// owner can fill them in. It also says whether the automatic WhatsApp
/// wishes (functions/index.js, 10:00 IST) are going out, since that decides
/// whether a manual wish is needed at all.
class OwnerBirthdaysPage extends ConsumerWidget {
  const OwnerBirthdaysPage({super.key});

  /// Days from today until [cust]'s next birthday, or null when none saved.
  static int? daysUntil(Customer cust, DateTime today) {
    final parsed = parseBirthday(cust.birthday);
    if (parsed == null) return null;
    final (month, day) = parsed;
    final base = DateTime(today.year, today.month, today.day);
    // 29 Feb in a non-leap year is celebrated on 28 Feb, like the function.
    DateTime on(int year) {
      final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
      return (month == 2 && day == 29 && !leap) ? DateTime(year, 2, 28) : DateTime(year, month, day);
    }

    var next = on(today.year);
    if (next.isBefore(base)) next = on(today.year + 1);
    return next.difference(base).inDays;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(appDataProvider).when(
          loading: () => const AppLoadingView(),
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
          data: (state) => _buildBody(context, ref, state),
        );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppData state) {
    final today = DateTime.now();
    final withDays = <(Customer, int)>[];
    final missing = <Customer>[];
    for (final c in state.customers) {
      final d = daysUntil(c, today);
      if (d == null) {
        missing.add(c);
      } else {
        withDays.add((c, d));
      }
    }
    withDays.sort((a, b) => a.$2.compareTo(b.$2));
    final todayList = withDays.where((e) => e.$2 == 0).toList();
    final weekList = withDays.where((e) => e.$2 >= 1 && e.$2 <= 6).toList();
    final monthList = withDays.where((e) => e.$2 >= 7 && e.$2 <= 30).toList();
    final autoOn = state.settings?.whatsappEnabled == true;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _autoWishCard(autoOn),
            const SizedBox(height: 8),
            if (withDays.isEmpty && missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No birthdays saved yet. Add them below - they power the automatic WhatsApp wishes.',
                  style: const TextStyle(fontSize: 13, color: AppTheme.slateLight),
                ),
              ),
            ..._section(context, ref, 'Today', todayList, autoOn, highlight: true),
            ..._section(context, ref, 'This week', weekList, autoOn),
            ..._section(context, ref, 'Next 30 days', monthList, autoOn),
            if (withDays.isNotEmpty && todayList.isEmpty && weekList.isEmpty && monthList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No birthdays in the next 30 days.', style: TextStyle(fontSize: 13, color: AppTheme.slateLight)),
              ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              DsSectionLabel('No birthday saved · ${missing.length}'),
              DsCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < missing.length && i < 50; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 66, color: AppTheme.borderSubtle),
                      DsListRow(
                        leading: DsAvatar(missing[i].name),
                        title: missing[i].name,
                        subtitle: missing[i].phone,
                        trailing: TextButton(
                          onPressed: () => showClientBirthdayDialog(context, ref, missing[i]),
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (missing.length > 50)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('and ${missing.length - 50} more - add birthdays from each client\'s page.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _autoWishCard(bool autoOn) {
    final color = autoOn ? AppTheme.accentGreen : AppTheme.slateLight;
    return DsCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: Icon(PhosphorIconsRegular.whatsappLogo, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  autoOn ? 'Automatic wishes are on' : 'Automatic wishes are off',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                ),
                const SizedBox(height: 2),
                Text(
                  autoOn
                      ? 'Clients who agreed to WhatsApp get a wish at 10 AM on their birthday.'
                      : 'Turn them on in Settings > Business > WhatsApp Messages, or send wishes yourself below.',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.slateLight, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<(Customer, int)> items,
    bool autoOn, {
    bool highlight = false,
  }) {
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      DsSectionLabel('$title · ${items.length}'),
      DsCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 66, color: AppTheme.borderSubtle),
              _row(context, ref, items[i].$1, items[i].$2, autoOn, highlight),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _row(BuildContext context, WidgetRef ref, Customer cust, int days, bool autoOn, bool highlight) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final date = DateTime.now().add(Duration(days: days));
    final when = days == 0
        ? 'Today'
        : days == 1
            ? 'Tomorrow'
            : days <= 6
                ? weekdays[date.weekday - 1]
                : 'In $days days';
    final autoWish = autoOn && cust.whatsappOptIn;

    return DsListRow(
      leading: DsAvatar(cust.name),
      title: cust.name,
      // "Today" alone when it's today; the date is only news otherwise.
      subtitle: days == 0
          ? (autoWish ? 'Today · auto wish' : 'Today')
          : '${formatBirthday(cust.birthday)} · $when',
      onTap: () => showClientBirthdayDialog(context, ref, cust),
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundAction(
            icon: PhosphorIconsRegular.whatsappLogo,
            tooltip: 'Send a wish on WhatsApp',
            filled: highlight,
            onTap: () => _sendWish(context, cust),
          ),
          const SizedBox(width: 6),
          _roundAction(
            icon: PhosphorIconsRegular.phone,
            tooltip: 'Call',
            onTap: () => _call(context, cust),
          ),
        ],
      ),
    );
  }

  Widget _roundAction({required IconData icon, required String tooltip, required VoidCallback onTap, bool filled = false}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? AppTheme.primaryBlue : AppTheme.primaryLight,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 17, color: filled ? Colors.white : AppTheme.primaryBlue),
          ),
        ),
      ),
    );
  }

  /// Opens a WhatsApp chat with a ready-written wish - the staff member just
  /// presses send. Separate from the automatic wishes, which need the
  /// client's consent and the salon's switch.
  void _sendWish(BuildContext context, Customer cust) {
    final number = whatsappNumber(cust.phone);
    final first = cust.name.trim().split(' ').first;
    final text = Uri.encodeComponent('Happy birthday, $first! Wishing you a wonderful year ahead.');
    if (number == null || !openLink('https://wa.me/$number?text=$text')) {
      _failed(context, '${cust.phone} does not look like a WhatsApp number.');
    }
  }

  void _call(BuildContext context, Customer cust) {
    final number = cust.phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (number.isEmpty || !openLink('tel:$number')) {
      _failed(context, 'Could not start a call to ${cust.phone}.');
    }
  }

  void _failed(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.accentRed, behavior: SnackBarBehavior.floating),
    );
  }
}
