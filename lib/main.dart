import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CLINIK',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Plus Jakarta Sans',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const OnboardingScreen(),
    );
  }
}