import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme.dart';

/// Shown for every tab's `asyncData.when(loading: ...)`, which in practice
/// means it is the first thing a user sees after tapping Log In while the
/// salon snapshot loads. A bare CircularProgressIndicator on an empty canvas
/// read as "broken", so this carries the brand mark, a determinate-looking
/// sweep and a line of copy that says what is happening.
class AppLoadingView extends StatefulWidget {
  final String? message;

  const AppLoadingView({super.key, this.message});

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.18 + (t * 0.22)),
                        blurRadius: 18 + (t * 10),
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(PhosphorIconsFill.scissors, color: Colors.white, size: 27),
                );
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 128,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.message ?? 'Loading your salon...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
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
