import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/stylux_logo.dart';

/// Premium Mobile Splash Screen for Stylux
///
/// Follows strict minimalist design guidelines:
/// - 390x844 responsive mobile-first canvas
/// - Obsidian luxury background (#090D16) with subtle ambient indigo bloom
/// - Centered vector logo with smooth fade + subtle scale (92% -> 100%)
/// - Staggered wordmark fade-in (1.2s total animation)
/// - Zero clutter, no buttons, no dashboard elements
class StyluxSplashScreen extends StatefulWidget {
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _wordmarkFadeAnimation;
  late final Animation<Offset> _wordmarkSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Dark immersive status bar for seamless splash experience
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF090D16),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    );

    // 1. Logo Fade-in: 0% -> 60% of timeline
    _logoFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.60, curve: Curves.easeOut),
    );

    // 2. Subtle Logo Scale: 0.92 -> 1.0 (0% -> 80% of timeline)
    _logoScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Staggered Wordmark Fade-in: 40% -> 95% of timeline
    _wordmarkFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.40, 0.95, curve: Curves.easeOut),
    );

    // 4. Ultra-subtle Wordmark micro slide-up: (0.40 -> 0.95)
    _wordmarkSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.95, curve: Curves.easeOutCubic),
      ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.height < 700;
    final iconSize = isCompact ? 84.0 : 104.0;
    final titleSize = isCompact ? 26.0 : 32.0;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16), // Premium deep obsidian canvas
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Subtle Ambient Indigo Glow behind center branding
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF4F46E5).withValues(alpha: 0.16),
                        const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Perfectly Centered Splash Branding
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo Mark with Scale & Fade Animation
                  FadeTransition(
                    opacity: _logoFadeAnimation,
                    child: ScaleTransition(
                      scale: _logoScaleAnimation,
                      child: StyluxLogoMark(
                        size: iconSize,
                      ),
                    ),
                  ),

                  SizedBox(height: isCompact ? 24 : 32),

                  // Wordmark with Staggered Fade & Slide
                  FadeTransition(
                    opacity: _wordmarkFadeAnimation,
                    child: SlideTransition(
                      position: _wordmarkSlideAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'STYLUX',
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.2,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SALON & STYLING OS',
                            style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                              fontSize: isCompact ? 10.5 : 12.0,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.8,
                              color: const Color(0xFF94A3B8), // Muted slate silver
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
