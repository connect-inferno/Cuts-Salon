import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme.dart';

/// Centered spinner used for every tab's `asyncData.when(loading: ...)` so
/// every screen shows the exact same loading treatment instead of each tab
/// re-declaring its own `Center(child: CircularProgressIndicator())`.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Icon + friendly message + Retry button, used for every tab's
/// `asyncData.when(error: ...)` instead of dumping the raw
/// `err.toString()` on screen with no way to recover.
class AppErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const AppErrorView({super.key, required this.error, required this.onRetry});

  String get _message {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring('Exception: '.length) : text;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsRegular.warningCircle, color: AppTheme.accentRed, size: 32),
            const SizedBox(height: 12),
            Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.slateMedium)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
