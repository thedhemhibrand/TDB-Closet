// lib/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdb_closet/utils.dart';
import 'login_page.dart'; // Import your login page

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _markOnboardingSeen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    // Navigate to login using MaterialPageRoute
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DhemiColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip button (top-right)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _markOnboardingSeen(context),
                  child: Text(
                    'Skip',
                    style: DhemiText.bodyMedium.copyWith(
                      color: DhemiColors.softPurple,
                    ),
                  ),
                ),
              ),

              // Main content
              Column(
                children: [
                  Image.asset(
                    'assets/images/onboarding2.png',
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to The Dhemhi Closet',
                    style: DhemiText.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DhemiColors.royalPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Discover curated fashion, exclusive drops, and effortless style—all in one place.',
                    style: DhemiText.bodyMedium.copyWith(
                      color: DhemiColors.gray800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              // Get Started button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _markOnboardingSeen(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DhemiColors.royalPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Get Started',
                    style: DhemiText.bodyLarge.copyWith(
                      color: DhemiColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension for vertical spacing (if you don't already have it)
extension SpacingExtension on num {
  SizedBox get verticalSpace => SizedBox(height: toDouble());
}
