import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/owner/owner_dashboard.dart';
import 'features/employee/employee_dashboard.dart';

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
    initialLocation: '/login',
    refreshListenable: listenable,
    redirect: (context, state) {
      final currentAuth = ref.read(authControllerProvider);
      final isLoggedIn = currentAuth.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        if (currentAuth.role == 'OWNER') {
          return '/owner/dashboard';
        } else {
          return '/employee/dashboard';
        }
      }

      return null;
    },
    routes: [
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
