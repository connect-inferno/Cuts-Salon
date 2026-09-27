import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_provider.dart';
import '../firebase/firestore_app_data.dart';
import '../firebase/salon_auth.dart';
import '../firebase/salon_firestore.dart';
import 'models.dart';

/// Salary records, loaded by the three screens that show them rather than at
/// sign-in: owner Payroll, an employee's profile card, and the employee's own
/// earnings history.
///
/// This query is unbounded - every record ever written, for every employee
/// when an owner is signed in - so unlike the other collections it does not
/// merely cost a fixed amount per load, it costs more every month the salon
/// stays open. Loading it on demand stops most sessions paying for it at
/// all; capping it by period is the other half of the fix and still to do.
///
/// Note `generateSalary` is deliberately NOT here: it settles commission
/// records as well as writing salaries, so it stays on AppDataNotifier
/// beside the commissions it invalidates, and refreshes this provider after.
class SalaryRecordsNotifier extends AutoDisposeAsyncNotifier<List<SalaryRecord>> {
  SalonFirestore? _fs;

  @override
  Future<List<SalaryRecord>> build() async {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated) return const [];

    final app = SalonAuth.currentApp(auth.salonId!);
    if (app == null) return const [];
    final fs = _fs = SalonFirestore(app);

    // Owners see the whole team, staff only their own - the same split
    // loadAppData applied via selfId, kept here so the rules see an
    // identical query shape to before.
    final selfId = auth.isOwner ? null : auth.userId;
    return (await fs.listSalaryRecords(employeeId: selfId)).map(salaryRecordFromFS).toList();
  }

  Future<void> markPaid(String id) async {
    final fs = _fs;
    if (fs == null) throw Exception('Not ready yet - try again in a moment');
    await fs.markSalaryPaid(id);

    final latest = state.value ?? const <SalaryRecord>[];
    state = AsyncData([
      for (final r in latest)
        if (r.id != id)
          r
        else
          SalaryRecord(
            id: r.id,
            employeeId: r.employeeId,
            month: r.month,
            year: r.year,
            baseSalary: r.baseSalary,
            commissionEarned: r.commissionEarned,
            deductions: r.deductions,
            totalPaid: r.totalPaid,
            status: 'PAID',
          ),
    ]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<SalaryRecord>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final fs = _fs;
      if (fs == null) return const <SalaryRecord>[];
      final auth = ref.read(authControllerProvider);
      final selfId = auth.isOwner ? null : auth.userId;
      return (await fs.listSalaryRecords(employeeId: selfId)).map(salaryRecordFromFS).toList();
    });
  }
}

final salaryRecordsProvider =
    AsyncNotifierProvider.autoDispose<SalaryRecordsNotifier, List<SalaryRecord>>(
        SalaryRecordsNotifier.new);
