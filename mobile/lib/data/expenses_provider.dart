import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_provider.dart';
import '../firebase/firestore_app_data.dart';
import '../firebase/firestore_models.dart';
import '../firebase/salon_auth.dart';
import '../firebase/salon_firestore.dart';
import 'models.dart';

/// Expenses, loaded when the Expenses screen is opened rather than at sign-in.
///
/// They used to ride along in [AppData], so every owner paid for up to 500
/// expense documents on every sign-in, pull-to-refresh and error retry -
/// including the overwhelming majority of sessions where nobody opens
/// Expenses at all. Nothing outside OwnerExpensesTab has ever read them.
///
/// `autoDispose` is the point: leave the screen and the list is dropped, so
/// re-opening it later re-reads rather than holding a snapshot that silently
/// ages for the rest of the session. This is the first collection moved out
/// of the single up-front load; salary records and archived clients are the
/// same shape and can follow.
class ExpensesNotifier extends AutoDisposeAsyncNotifier<List<Expense>> {
  SalonFirestore? _fs;

  @override
  Future<List<Expense>> build() async {
    final auth = ref.watch(authControllerProvider);
    // Owner-only, matching the gate this had inside loadAppData: staff have
    // no expenses screen and the rules would refuse them anyway.
    if (!auth.isAuthenticated || !auth.isOwner) return const [];

    final app = SalonAuth.currentApp(auth.salonId!);
    if (app == null) return const [];
    final fs = _fs = SalonFirestore(app);

    return (await fs.listExpenses()).map(expenseFromFS).toList();
  }

  Future<void> add({
    required String title,
    required double amount,
    required String category,
    required String date,
    String? notes,
  }) async {
    final fs = _fs;
    if (fs == null) throw Exception('Not ready yet - try again in a moment');

    final createdFS = await fs.createExpense(FSExpense(
      id: '',
      title: title,
      amount: amount,
      category: category,
      date: DateTime.parse(date),
      notes: notes,
    ));

    // Re-read rather than patching a snapshot captured before the await, for
    // the same reason the mutations in AppDataNotifier do.
    final latest = state.value ?? const <Expense>[];
    state = AsyncData([expenseFromFS(createdFS), ...latest]);
  }

  /// Removes one expense. The local list is filtered rather than re-listed,
  /// so correcting a typo costs one delete and no extra read of the other 499
  /// documents - the same reason [add] prepends instead of refetching.
  Future<void> remove(String id) async {
    final fs = _fs;
    if (fs == null) throw Exception('Not ready yet - try again in a moment');
    await fs.deleteExpense(id);
    final latest = state.value ?? const <Expense>[];
    state = AsyncData(latest.where((e) => e.id != id).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<Expense>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final fs = _fs;
      if (fs == null) return const <Expense>[];
      return (await fs.listExpenses()).map(expenseFromFS).toList();
    });
  }
}

final expensesProvider =
    AsyncNotifierProvider.autoDispose<ExpensesNotifier, List<Expense>>(ExpensesNotifier.new);
