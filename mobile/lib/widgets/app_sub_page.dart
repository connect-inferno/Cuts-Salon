import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_page_header.dart';
import 'app_page_route.dart';

/// Pushes [child] as a full page with the standard back header.
///
/// Used for the drawer's destinations - Inventory, Expenses, Reports,
/// Branches - which are real places rather than settings. Anything that
/// configures or supports a section belongs inside that section's settings
/// (see [AppSettingsPage]), not behind another push from here.
Future<T?> openAppSubPage<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  List<AppPageAction> actions = const [],
}) {
  return Navigator.of(context).push<T>(
    AppSlidePageRoute<T>(
      page: AppSubPage(
        title: title,
        subtitle: subtitle,
        actions: actions,
        child: child,
      ),
    ),
  );
}

class AppSubPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<AppPageAction> actions;

  const AppSubPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: Column(
        children: [
          AppPageHeader(
            title: title,
            subtitle: subtitle,
            leading: AppPageLeading.back,
            actions: actions,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
