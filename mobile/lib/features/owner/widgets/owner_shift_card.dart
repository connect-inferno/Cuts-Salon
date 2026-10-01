import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/models.dart';
import '../../../theme.dart';

/// The owner's own shift, on the attendance screen they already use to mark
/// everyone else's.
///
/// An owner is an `employees/{uid}` document like anyone else, so they appear
/// in the roster below and could be given a status letter there - but a
/// letter records no hours. The roster writes PRESENT/LATE/ABSENT and nothing
/// more, so an owner who works a full Saturday had no clock-in time, no
/// clock-out, and no shift length anywhere in the app, while every stylist
/// did. This is the same punch their staff make, using the same
/// `clockIn`/`clockOut` calls, which are role-agnostic already.
///
/// Deliberately presentational: it takes the record and two callbacks rather
/// than reaching for providers, so the whole thing can be pumped in a test
/// without Firebase. The screen that hosts it owns the wiring.
class OwnerShiftCard extends StatelessWidget {
  /// Today's record for the owner, or null if they have not punched at all.
  final AttendanceRecord? today;

  /// A punch is in flight - both buttons go quiet rather than queueing.
  final bool submitting;

  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  /// Evaluated once by the caller so the elapsed figure and the roster's
  /// idea of "today" cannot disagree across midnight.
  final DateTime now;

  const OwnerShiftCard({
    super.key,
    required this.today,
    required this.submitting,
    required this.onClockIn,
    required this.onClockOut,
    required this.now,
  });

  bool get _isClockedIn => today?.clockIn != null && today?.clockOut == null;
  bool get _isDone => today?.clockIn != null && today?.clockOut != null;

  static String formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Whole hours and minutes. Seconds would imply a precision the punch does
  /// not have, and a ticking figure is not worth a timer on this screen.
  static String formatDuration(Duration d) {
    if (d.isNegative) return '0m';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final record = today;
    final clockIn = record?.clockIn;
    final clockOut = record?.clockOut;

    final Color accent;
    final Color accentBg;
    final String heading;
    final String detail;

    if (_isDone) {
      accent = AppTheme.slateMedium;
      accentBg = const Color(0xFFF1F5F9);
      heading = 'Shift finished';
      detail =
          '${formatTime(clockIn!)} - ${formatTime(clockOut!)} · ${formatDuration(clockOut.difference(clockIn))}';
    } else if (_isClockedIn) {
      accent = AppTheme.accentGreen;
      accentBg = AppTheme.accentGreenBg;
      heading = 'On shift';
      detail =
          'Since ${formatTime(clockIn!)} · ${formatDuration(now.difference(clockIn))} so far';
    } else {
      accent = AppTheme.slateLight;
      accentBg = const Color(0xFFF1F5F9);
      heading = 'Not clocked in';
      detail = 'Your own hours are recorded the same way your staff\'s are.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: AppTheme.slateDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _isDone
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsRegular.clock,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Your shift',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.slateDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            heading,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slateLight,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _isDone
                // Deliberately no re-punch. A second clock-in would overwrite
                // the day's clockIn and lose the shift that was worked; the
                // roster below is where a finished day gets corrected.
                ? _doneNote()
                : ElevatedButton.icon(
                    onPressed: submitting
                        ? null
                        : (_isClockedIn ? onClockOut : onClockIn),
                    icon: submitting
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isClockedIn
                                ? PhosphorIconsBold.signOut
                                : PhosphorIconsBold.fingerprint,
                            size: 16,
                          ),
                    label: Text(
                      submitting
                          ? 'Saving...'
                          : _isClockedIn
                              ? 'Clock Out'
                              : 'Clock In',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isClockedIn
                          ? AppTheme.slateDark
                          : AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFC7D2FE),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _doneNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: const Row(
        children: [
          Icon(
            PhosphorIconsRegular.checkCircle,
            size: 14,
            color: AppTheme.slateLight,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Logged for today.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.slateLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
