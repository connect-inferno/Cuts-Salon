import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Month and year for a payroll run, chosen in place.
///
/// Replaces the two side-by-side [DropdownButtonFormField]s this used to be.
/// They overflowed the dialog by 18px once a long month name was selected,
/// and each opened a full-height menu across the whole screen to choose from
/// twelve items - for a choice that fits inside the dialog itself.
///
/// A grid also makes "which months can I still run" an at-a-glance answer:
/// payroll sums what has already been earned, so a month that has not
/// happened yet can only produce an empty record. The dropdowns offered those
/// months anyway, and nothing downstream rejected the choice.
class PayPeriodPicker extends StatelessWidget {
  final int month;
  final int year;

  /// Injected rather than read from the clock so the boundary behaviour is
  /// testable, and so every chip in one build agrees on what "future" means.
  final DateTime now;

  final void Function(int month, int year) onChanged;

  const PayPeriodPicker({
    super.key,
    required this.month,
    required this.year,
    required this.now,
    required this.onChanged,
  });

  bool _isFuture(int m, int y) =>
      y > now.year || (y == now.year && m > now.month);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              PhosphorIconsRegular.calendarBlank,
              size: 14,
              color: AppTheme.slateLight,
            ),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'Pay period',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slateMedium,
                ),
              ),
            ),
            const Spacer(),
            // Only ever two years to choose from, so they sit inline as a
            // segmented control rather than behind a second menu.
            for (var y = now.year - 1; y <= now.year; y++) ...[
              if (y > now.year - 1) const SizedBox(width: 6),
              _chip(
                label: '$y',
                selected: year == y,
                // Switching to the current year can strand the selection on a
                // month that has not happened yet; pull it back to this month.
                onTap: () => onChanged(_isFuture(month, y) ? now.month : month, y),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var col = 0; col < 4; col++) ...[
                if (col > 0) const SizedBox(width: 6),
                // Expanded, not content-sized chips in a Wrap: equal columns
                // cannot overflow the dialog however wide the labels render.
                Expanded(child: _monthChip(row * 4 + col + 1)),
              ],
            ],
          ),
        ],
        const SizedBox(height: 12),
        _summary(),
      ],
    );
  }

  Widget _monthChip(int m) {
    final disabled = _isFuture(m, year);
    return _chip(
      label: _monthNames[m - 1].substring(0, 3),
      selected: month == m && !disabled,
      disabled: disabled,
      onTap: disabled ? null : () => onChanged(m, year),
    );
  }

  /// Spells the choice out in full. The grid shows three-letter months, and
  /// a payroll run is not something to get wrong by misreading "Jun" for
  /// "Jul".
  Widget _summary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primarySoft),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsBold.checkCircle,
            size: 14,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Running for ${_monthNames[month - 1]} $year',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDarker,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryBlue
              : disabled
                  ? const Color(0xFFF8FAFC)
                  : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : AppTheme.borderSubtle,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? Colors.white
                : disabled
                    ? AppTheme.textMuted
                    : AppTheme.slateMedium,
          ),
        ),
      ),
    );
  }
}
