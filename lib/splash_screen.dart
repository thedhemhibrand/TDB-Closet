// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdb_closet/login_page.dart';
import 'package:tdb_closet/onboarding_screen.dart';
import 'package:tdb_closet/utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _typewriterController;
  late Animation<double> _opacityAnimation;
  late AnimationController _cursorController;
  late Animation<double> _cursorOpacity;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkAndNavigate();
  }

  void _initAnimations() {
    _typewriterController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _typewriterController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutSine),
      ),
    );

    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _cursorOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cursorController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );

    _typewriterController.forward();
  }

  Future<void> _checkAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

    // Navigate using MaterialPageRoute instead of named routes
    if (seenOnboarding) {
      // Navigate to Login Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else {
      // Navigate to Onboarding (uncomment when you have onboarding screen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );

      // For now, go directly to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _typewriterController,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'The Dhemhi Closet',
                      style: DhemiText.logo.copyWith(
                        fontSize: 36,
                        color: DhemiColors.royalPurple.withOpacity(
                          _opacityAnimation.value,
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _cursorOpacity,
                      child: Text(
                        '|',
                        style: DhemiText.logo.copyWith(
                          fontSize: 36,
                          color: DhemiColors.royalPurple,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _typewriterController,
                      curve: const Interval(0.9, 1.0, curve: Curves.easeInOut),
                    ),
                  ),
                  child: Text(
                    'v1.0.0',
                    style: DhemiText.bodySmall.copyWith(
                      color: DhemiColors.softPurple,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
