import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/whatsapp_theme.dart';

class ModernSplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const ModernSplashScreen({super.key, required this.onFinish});

  @override
  State<ModernSplashScreen> createState() => _ModernSplashScreenState();
}

class _ModernSplashScreenState extends State<ModernSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
    );

    _rippleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.95, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) {
        widget.onFinish();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? WhatsAppTheme.darkBg : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient glowing gradient background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _rippleAnimation,
                builder: (context, _) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.85 + (_rippleAnimation.value * 0.25),
                        colors: [
                          WhatsAppTheme.primaryTeal.withValues(
                            alpha: isDark ? 0.18 : 0.10,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Center Branding (Logo & Title)
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Icon with Modern Glow & Wave Ring
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF25D366),
                            Color(0xFF00A884),
                            Color(0xFF128C7E),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: WhatsAppTheme.primaryTeal.withValues(
                              alpha: isDark ? 0.45 : 0.35,
                            ),
                            blurRadius: 36,
                            spreadRadius: 4,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // App Name
                    Text(
                      'RenChat',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? WhatsAppTheme.darkTextPrimary : const Color(0xFF111B21),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Simple. Reliable. Private.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        color: isDark ? WhatsAppTheme.darkTextSecondary : const Color(0xFF667781),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Meta Tag: End-to-End Encrypted & Modern Tag
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: isDark ? WhatsAppTheme.darkTextSecondary : const Color(0xFF667781),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'End-to-end encrypted',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                            color: isDark ? WhatsAppTheme.darkTextSecondary : const Color(0xFF667781),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'from RENATA OFFICIAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: WhatsAppTheme.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
