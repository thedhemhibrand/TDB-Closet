import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tdb_closet/onboarding_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Dhemhi Closet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const OnboardingScreen(), // Simple home property
      debugShowCheckedModeBanner: false, // Optional: removes debug banner
    );
  }
}
