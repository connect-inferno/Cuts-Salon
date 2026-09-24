import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/owner/owner_dashboard.dart';
import 'features/employee/employee_dashboard.dart';
import 'theme.dart';
import 'widgets/stylux_logo.dart';

class RouterListenable extends ChangeNotifier {
  final Ref _ref;

  RouterListenable(this._ref) {
    _ref.listen(authControllerProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final routerListenableProvider = Provider((ref) => RouterListenable(ref));

final goRouterProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerListenableProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final currentAuth = ref.read(authControllerProvider);
      final isSplash = state.matchedLocation == '/splash';

      // Restoring a persisted Firebase session is async - holding here
      // (instead of defaulting straight to /login) is what stops an
      // already-logged-in user from seeing the login form flash before
      // bouncing to their dashboard.
      if (!currentAuth.sessionChecked) {
        return isSplash ? null : '/splash';
      }

      final isLoggedIn = currentAuth.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn || isSplash) {
        return currentAuth.role == 'OWNER' ? '/owner/dashboard' : '/employee/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _fadeSlidePage(state, const _SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadeSlidePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/owner/dashboard',
        pageBuilder: (context, state) => _fadeSlidePage(state, const OwnerDashboard()),
      ),
      GoRoute(
        path: '/employee/dashboard',
        pageBuilder: (context, state) => _fadeSlidePage(state, const EmployeeDashboard()),
      ),
    ],
  );
});

// Fade + subtle upward slide for top-level route changes (login <->
// dashboards) - matches the AppPageSwitcher transition used for in-app
// tab/screen switching so navigation feels consistent everywhere.
CustomTransitionPage _fadeSlidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

// Shown only while the initial auto-login check is in flight (see
// AuthState.sessionChecked) - never long enough to need its own animation,
// just enough to avoid a bare white frame between app boot and the first
// real route.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyluxLogo.hero(subtitle: null),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}
