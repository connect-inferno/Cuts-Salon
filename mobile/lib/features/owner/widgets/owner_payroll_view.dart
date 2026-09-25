import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/app_data.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../theme.dart';
import '../../../widgets/async_state_views.dart';

const _kMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _rupees(double amount) {
  final whole = amount.round().toString();
  if (whole.length <= 3) return '₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole.substring(0, whole.length - 3);
  final grouped = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '₹$grouped,$last3';
}

/// Payroll across the whole team, as a section of Team Settings.
///
/// What each person is owed was only ever visible one employee at a time,
/// on their own profile page - so "what does this month cost me" meant
/// opening every staff member in turn and adding it up by hand. The numbers
/// here are the same ones their profile shows: base salary from their
/// record, and [AppData.pendingCommissionFor] for commission, so the two
/// views can't disagree.
class OwnerPayrollView extends ConsumerWidget {
  const OwnerPayrollView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appDataProvider);

    return asyncData.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(
        error: err,
        onRetry: () => ref.read(appDataProvider.notifier).refresh(),
      ),
      data: (state) {
        if (state.employees.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No staff on the roster yet.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slateLight,
                ),
              ),
            ),
          );
        }

        final now = DateTime.now();
        final rows = state.employees.map((emp) {
          final pending = state.pendingCommissionFor(emp.id);
          final paidThisMonth = state.salaryRecords.any(
            (s) => s.employeeId == emp.id && s.month == now.month && s.year == now.year,
          );
          return _PayrollRow(
            employee: emp,
            commission: pending.total,
            alreadyPaid: paidThisMonth,
          );
        }).toList();

        final totalBase = state.employees.fold<double>(0, (s, e) => s + e.baseSalary);
        final totalCommission = rows.fold<double>(0, (s, r) => r.commission + s);
        final outstandingRows = rows.where((r) => !r.alreadyPaid).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_kMonths[now.month - 1].toUpperCase()} ${now.year} PAYROLL',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _summaryRow('Base salaries', _rupees(totalBase)),
                  _summaryRow('Commission owed', _rupees(totalCommission)),
                  const Divider(height: 18, color: Color(0xFFC7D2FE)),
                  _summaryRow(
                    'Total if paid now',
                    _rupees(totalBase + totalCommission),
                    emphasise: true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    outstandingRows == 0
                        ? 'Every slip for this month has been generated.'
                        : '$outstandingRows slip${outstandingRows == 1 ? '' : 's'} not yet generated this month.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final row in rows) ...[
              _buildStaffRow(row),
              const SizedBox(height: 9),
            ],
          ],
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasise = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasise ? 13.5 : 12.5,
              fontWeight: emphasise ? FontWeight.w800 : FontWeight.w600,
              color: emphasise ? AppTheme.slateDark : AppTheme.slateMedium,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasise ? 17 : 12.5,
              fontWeight: emphasise ? FontWeight.w800 : FontWeight.w700,
              color: emphasise ? AppTheme.slateDark : AppTheme.slateMedium,
              letterSpacing: emphasise ? -0.5 : 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffRow(_PayrollRow row) {
    final total = row.employee.baseSalary + row.commission;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              row.employee.name
                  .split(' ')
                  .where((n) => n.isNotEmpty)
                  .map((n) => n[0].toUpperCase())
                  .take(2)
                  .join(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.employee.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slateDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Base ${_rupees(row.employee.baseSalary)} · commission ${_rupees(row.commission)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slateLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _rupees(total),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.slateDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: row.alreadyPaid ? AppTheme.accentGreenBg : AppTheme.accentAmberBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  row.alreadyPaid ? 'Slip made' : 'Pending',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: row.alreadyPaid ? AppTheme.accentGreen : AppTheme.accentAmber,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayrollRow {
  final EmployeeProfile employee;
  final double commission;
  final bool alreadyPaid;

  const _PayrollRow({
    required this.employee,
    required this.commission,
    required this.alreadyPaid,
  });
}
