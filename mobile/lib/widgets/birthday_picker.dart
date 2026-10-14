import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/birthday.dart';
import '../theme.dart';

/// Day + month pickers for a client's birthday (no year - see
/// data/birthday.dart). Reports "MM-DD" once both are chosen, null while
/// either is empty or after Clear.
///
/// Used by Add Customer and by the customer options sheet's
/// "Birthday & WhatsApp" dialog, so both store the same shape.
class BirthdayPicker extends StatefulWidget {
  final String? initial;
  final ValueChanged<String?> onChanged;

  const BirthdayPicker({super.key, this.initial, required this.onChanged});

  @override
  State<BirthdayPicker> createState() => _BirthdayPickerState();
}

class _BirthdayPickerState extends State<BirthdayPicker> {
  int? _month;
  int? _day;

  @override
  void initState() {
    super.initState();
    final parsed = parseBirthday(widget.initial);
    if (parsed != null) {
      _month = parsed.$1;
      _day = parsed.$2;
    }
  }

  void _set({int? month, int? day, bool clear = false}) {
    setState(() {
      if (clear) {
        _month = null;
        _day = null;
      } else {
        if (month != null) _month = month;
        if (day != null) _day = day;
        // 31 Jan -> Feb would otherwise leave an impossible "02-31".
        if (_month != null && _day != null && _day! > daysInBirthdayMonth(_month!)) {
          _day = daysInBirthdayMonth(_month!);
        }
      }
    });
    widget.onChanged(_month != null && _day != null ? birthdayKey(_month!, _day!) : null);
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = _month == null ? 31 : daysInBirthdayMonth(_month!);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _dropdown<int>(
            key: const Key('birthdayDay'),
            hint: 'Day',
            icon: PhosphorIconsRegular.cake,
            value: _day,
            items: [for (var d = 1; d <= maxDay; d++) DropdownMenuItem(value: d, child: Text('$d'))],
            onChanged: (d) => _set(day: d),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: _dropdown<int>(
            key: const Key('birthdayMonth'),
            hint: 'Month',
            value: _month,
            items: [
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text(birthdayMonthNames[m - 1])),
            ],
            onChanged: (m) => _set(month: m),
          ),
        ),
        if (_month != null || _day != null)
          IconButton(
            tooltip: 'Clear birthday',
            onPressed: () => _set(clear: true),
            icon: const Icon(PhosphorIconsRegular.x, size: 16, color: AppTheme.slateLight),
          ),
      ],
    );
  }

  Widget _dropdown<T>({
    required Key key,
    required String hint,
    IconData? icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppTheme.borderSubtle),
    );
    return DropdownButtonFormField<T>(
      key: key,
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      menuMaxHeight: 320,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textMuted),
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: AppTheme.slateLight),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
        ),
      ),
    );
  }
}

/// The consent checkbox that goes with it - one wording everywhere it's asked.
class WhatsAppOptInTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const WhatsAppOptInTile({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: const Key('whatsappOptIn'),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: const Color(0xFF16A34A),
      title: const Text(
        'OK to send WhatsApp messages',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
      ),
      subtitle: const Text(
        'Bill after each visit, birthday wishes and visit reminders. Ask the client first.',
        style: TextStyle(fontSize: 11, color: AppTheme.slateLight),
      ),
    );
  }
}
