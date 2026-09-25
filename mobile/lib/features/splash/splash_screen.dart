import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/stylux_logo.dart';

/// Splash shown while the persisted Firebase session is restored
/// (AuthController._tryAutoLogin). The router holds this screen until
/// AuthState.sessionChecked flips, so it has to look right both for the
/// common sub-second case and for a slow cold start - hence the staged
/// animation followed by a quiet progress hint rather than a fixed timer.
///
/// - Obsidian canvas (#090D16) with a slowly breathing indigo bloom
/// - Logo fades and scales 92% -> 100%
/// - Wordmark staggers in behind it
/// - A thin indeterminate bar fades in last, only once the brand has landed
class StyluxSplashScreen extends StatefulWidget {
  /// Optional: only used when this screen drives its own navigation. The
  /// router does not pass it - there the redirect happens when auth resolves.
  final VoidCallback? onAnimationComplete;
  final Duration totalDuration;

  const StyluxSplashScreen({
    super.key,
    this.onAnimationComplete,
    this.totalDuration = const Duration(milliseconds: 1400),
  });

  @override
  State<StyluxSplashScreen> createState() => _StyluxSplashScreenState();
}

class _StyluxSplashScreenState extends State<StyluxSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _ambientController;
  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _wordmarkFadeAnimation;
  late final Animation<Offset> _wordmarkSlideAnimation;
  late final Animation<double> _hintFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Dark immersive system bars so the canvas runs edge to edge.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF090D16),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(vsync: this, duration: widget.totalDuration);

    // Runs forever: on a slow session restore the screen should still feel
    // alive rather than frozen on a finished one-shot animation.
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _logoFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _wordmarkFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );

    _wordmarkSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // Last in, so a fast restore never flashes a loading bar.
    _hintFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.height < 700;
    final iconSize = isCompact ? 84.0 : 104.0;
    final titleSize = isCompact ? 26.0 : 32.0;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Breathing ambient bloom behind the mark.
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _ambientController,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(_ambientController.value);
                    final size = 300.0 + (t * 56);
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF4F46E5).withValues(alpha: 0.12 + (t * 0.08)),
                            const Color(0xFF7C3AED).withValues(alpha: 0.06 + (t * 0.04)),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _logoFadeAnimation,
                    child: ScaleTransition(
                      scale: _logoScaleAnimation,
                      child: StyluxLogoMark(size: iconSize),
                    ),
                  ),
                  SizedBox(height: isCompact ? 24 : 32),
                  FadeTransition(
                    opacity: _wordmarkFadeAnimation,
                    child: SlideTransition(
                      position: _wordmarkSlideAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'STYLUX',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.2,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Hairline rule between wordmark and tagline - the
                          // tagline alone floated without it.
                          Container(
                            width: 46,
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF6366F1).withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'SALON & STYLING OS',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: isCompact ? 10.5 : 12.0,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.8,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 36 : 48),
                  FadeTransition(
                    opacity: _hintFadeAnimation,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 132,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              minHeight: 2.5,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Restoring your session',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                            color: Colors.white.withValues(alpha: 0.42),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quiet footer mark.
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: FadeTransition(
                opacity: _hintFadeAnimation,
                child: Text(
                  'Secure multi-salon workspace',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
