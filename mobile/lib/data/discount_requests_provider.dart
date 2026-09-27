import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_provider.dart';
import '../firebase/firestore_app_data.dart';
import '../firebase/salon_auth.dart';
import '../firebase/salon_firestore.dart';
import 'models.dart';

/// The full discount-request list, for the owner's Discounts screen.
///
/// An owner no longer carries these in AppData: ten of the twelve places
/// that read them only wanted a pending count for a badge, which is now a
/// count() aggregation costing one read instead of fifty. This is the one
/// screen that genuinely needs the documents, so it fetches them itself.
///
/// Staff are unaffected - their own requests are already filtered to them
/// and stay in AppData, so their Discounts tab reads from there.
class DiscountRequestsNotifier extends AutoDisposeAsyncNotifier<List<DiscountRequest>> {
  @override
  Future<List<DiscountRequest>> build() async {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated || !auth.isOwner) return const [];

    final app = SalonAuth.currentApp(auth.salonId!);
    if (app == null) return const [];
    final fs = SalonFirestore(app);

    return (await fs.listDiscountRequests()).map(discountRequestFromFS).toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final discountRequestsProvider =
    AsyncNotifierProvider.autoDispose<DiscountRequestsNotifier, List<DiscountRequest>>(
        DiscountRequestsNotifier.new);
