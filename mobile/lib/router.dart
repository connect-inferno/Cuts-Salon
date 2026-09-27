import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/owner/owner_dashboard.dart';
import 'features/employee/employee_dashboard.dart';
import 'features/splash/splash_screen.dart';
import 'widgets/app_page_route.dart';

/// The single route every stacked screen is pushed onto. One path rather
/// than a route per screen because the pages carry their own state (a
/// customer id, a list of settings sections) that no URL reconstructs.
const _kStackedPath = '/page';

/// Pushes [page] over the current screen, with a browser history entry.
///
/// Use this instead of Navigator.push for anything full-screen: the history
/// entry is what makes the iOS back-swipe pop this page rather than unwind
/// the whole app to the splash screen.
Future<T?> pushAppRoute<T>(BuildContext context, Widget page) =>
    GoRouter.of(context).push<T>(_kStackedPath, extra: page);

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
        pageBuilder: (context, state) => _fadeSlidePage(state, const StyluxSplashScreen()),
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
      // Every screen that opens on top of a dashboard - a client, a staff
      // member, Expenses, any settings page - comes through here.
      //
      // They used to be Navigator.push()es, which never touch the URL. That
      // left the browser's history holding only /splash -> /login ->
      // /dashboard, so iOS Safari's swipe-back gesture walked THAT instead
      // of the screens on screen: the swipe revealed the splash, the app
      // re-ran its session restore, and the page the user swiped from was
      // gone. Routing them through GoRouter gives each push a history entry,
      // so back - gesture, browser button or Android - pops one screen.
      //
      // The widget travels in `extra`, which is deliberately not encoded in
      // the URL and does not survive a reload. Landing here without one
      // means a refresh or a pasted link, so it bounces to the dashboard
      // rather than rendering a blank page.
      GoRoute(
        path: _kStackedPath,
        redirect: (context, state) {
          if (state.extra is Widget) return null;
          final auth = ref.read(authControllerProvider);
          if (!auth.isAuthenticated) return '/login';
          return auth.role == 'OWNER' ? '/owner/dashboard' : '/employee/dashboard';
        },
        pageBuilder: (context, state) => AppSlideTransitionPage<void>(
          key: state.pageKey,
          child: state.extra as Widget,
        ),
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
