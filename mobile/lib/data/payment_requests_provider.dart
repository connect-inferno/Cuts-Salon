import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_provider.dart';
import '../firebase/firestore_models.dart';
import '../firebase/salon_auth.dart';
import '../firebase/salon_firestore.dart';
import 'app_data_provider.dart';
import 'models.dart';

PaymentRequest _fromFS(FSPaymentRequest r) => PaymentRequest(
      id: r.id,
      billId: r.billId,
      customerId: r.customerId,
      customerName: r.customerName,
      invoiceNumber: r.invoiceNumber,
      amount: r.amount,
      method: r.method,
      requestedBy: r.requestedBy,
      requestedByName: r.requestedByName,
      note: r.note,
      status: r.status,
      createdAt: r.createdAt,
    );

/// Settlement requests, loaded when someone opens the queue rather than at
/// sign-in.
///
/// Same shape and the same reasoning as [ExpensesNotifier]: nothing outside
/// the two screens that render these ever reads them, so making every login
/// pay for the documents would be waste. The owner's *badge* does not come
/// from here - it is an aggregate count taken during the initial load (see
/// SalonFirestore.countPendingPaymentRequests), which is a fraction of the
/// cost of the documents themselves.
///
/// Staff see only their own requests; the owner sees the salon's. That split
/// is applied here rather than in the rules because Firestore rules gate
/// documents, not queries - the same note that sits atop firestore.rules.
class PaymentRequestsNotifier extends AutoDisposeAsyncNotifier<List<PaymentRequest>> {
  SalonFirestore? _fs;
  bool _isOwner = false;

  @override
  Future<List<PaymentRequest>> build() async {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated) return const [];

    final app = SalonAuth.currentApp(auth.salonId!);
    if (app == null) return const [];
    final fs = _fs = SalonFirestore(app);
    _isOwner = auth.isOwner;

    final rows = await fs.listPaymentRequests(
      requestedBy: auth.isOwner ? null : auth.userId,
    );
    return rows.map(_fromFS).toList();
  }

  /// Raises a request against one unpaid bill. Staff-side entry point.
  Future<void> request({
    required String billId,
    required String customerId,
    String? customerName,
    String? invoiceNumber,
    required double amount,
    required String method,
    String? note,
  }) async {
    final fs = _fs;
    if (fs == null) throw Exception('Not ready yet - try again in a moment');
    if (amount <= 0) throw Exception('Enter an amount greater than zero');

    final auth = ref.read(authControllerProvider);
    // The requester's name is resolved from the already-loaded snapshot, so
    // stamping it costs no read.
    final me = ref.read(appDataProvider).valueOrNull?.employeeById(auth.userId ?? '');

    final created = await fs.createPaymentRequest(FSPaymentRequest(
      id: '',
      billId: billId,
      customerId: customerId,
      customerName: customerName,
      invoiceNumber: invoiceNumber,
      amount: amount,
      method: method,
      requestedBy: auth.userId!,
      requestedByName: me?.name ?? auth.name,
      note: note,
    ));

    final latest = state.value ?? const <PaymentRequest>[];
    state = AsyncData([_fromFS(created), ...latest]);
  }

  /// Owner-side decision.
  ///
  /// Approving records the real payment first and only then stamps the
  /// request. If the stamp fails, the money is still correctly recorded and
  /// the request stays PENDING - visible, and safe to resolve again, because
  /// resolve refuses anything that is no longer PENDING. The other order
  /// would leave an APPROVED request over a payment that never happened.
  Future<void> resolve(String id, {required bool approve}) async {
    final fs = _fs;
    if (fs == null) throw Exception('Not ready yet - try again in a moment');
    if (!_isOwner) throw Exception('Only the owner can decide a settlement request');

    final match = (state.value ?? const <PaymentRequest>[]).where((r) => r.id == id);
    if (match.isEmpty) throw Exception('Request not found');
    final req = match.first;
    if (req.status != 'PENDING') throw Exception('This request has already been decided');

    if (approve) {
      await ref.read(appDataProvider.notifier).recordPayment(
            billId: req.billId,
            amount: req.amount,
            method: req.method,
            note: 'Approved settlement request from ${req.requestedByName ?? 'staff'}',
          );
    }
    final resolved = await fs.resolvePaymentRequest(id, approve: approve);

    final latest = state.value ?? const <PaymentRequest>[];
    state = AsyncData([
      for (final r in latest)
        if (r.id == id) _fromFS(resolved) else r,
    ]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<PaymentRequest>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final fs = _fs;
      if (fs == null) return const <PaymentRequest>[];
      final auth = ref.read(authControllerProvider);
      final rows = await fs.listPaymentRequests(
        requestedBy: auth.isOwner ? null : auth.userId,
      );
      return rows.map(_fromFS).toList();
    });
  }
}

final paymentRequestsProvider =
    AsyncNotifierProvider.autoDispose<PaymentRequestsNotifier, List<PaymentRequest>>(
        PaymentRequestsNotifier.new);
