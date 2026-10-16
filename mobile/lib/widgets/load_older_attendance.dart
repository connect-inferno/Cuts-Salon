import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_data_provider.dart';
import '../theme.dart';

/// The foot of an attendance history list: "Load older days" until the
/// whole history is loaded, then a quiet "That's the full history".
///
/// Sign-in loads only the newest records; this fetches the next page
/// (AppDataNotifier.loadOlderAttendance) into AppData, so the list above -
/// which reads AppData - simply grows.
class LoadOlderAttendance extends ConsumerStatefulWidget {
  const LoadOlderAttendance({super.key});

  @override
  ConsumerState<LoadOlderAttendance> createState() => _LoadOlderAttendanceState();
}

class _LoadOlderAttendanceState extends ConsumerState<LoadOlderAttendance> {
  bool _loading = false;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(appDataProvider.notifier).loadOlderAttendance();
    } catch (e) {
      _error = "Couldn't load older days. Check the connection and try again.";
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the button turns into the end note once a page comes back
    // short (the notifier flips hasOlderAttendance before it updates state).
    ref.watch(appDataProvider);
    final hasMore = ref.read(appDataProvider.notifier).hasOlderAttendance;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : !hasMore
                ? const Text("That's the full history", style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.accentRed)),
                        ),
                      OutlinedButton(onPressed: _load, child: const Text('Load older days')),
                    ],
                  ),
      ),
    );
  }
}
