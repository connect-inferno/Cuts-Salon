import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_data_provider.dart';
import '../theme.dart';

/// Swipe down from the top of a main tab to reload the salon's data.
///
/// Wraps each bottom-bar tab (owner and staff). Every page under it can be
/// pulled even when its content is shorter than the screen - a nearly
/// empty list is exactly when someone pulls to see if anything new came
/// in - so scroll views without their own physics get always-scrollable
/// physics here.
class PullToRefresh extends ConsumerWidget {
  final Widget child;

  /// What a pull does. Defaults to reloading the salon's data; tests pass
  /// their own.
  final Future<void> Function()? onRefresh;

  const PullToRefresh({super.key, required this.child, this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      backgroundColor: Colors.white,
      onRefresh: onRefresh ?? () => ref.read(appDataProvider.notifier).refresh(),
      // Any vertical scroll in the page, not only the outermost one - some
      // tabs nest their list one level down.
      notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
      // The app's own scroll behaviour (scrollbars, drag devices) with only
      // the physics changed, so short pages can still be pulled.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        ),
        child: child,
      ),
    );
  }
}
