import 'package:clinik/screens/home_screen.dart';
import 'package:clinik/screens/onboarding_screen.dart';
import 'package:clinik/screens/nutrition_score_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_colors.dart';
import 'core/local_config.dart';

// Importa tus pantallas
import 'screens/medications_screen.dart';
import 'screens/records_screen.dart';
import 'screens/medical_followup_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'widgets/main_bottom_navigation.dart';

// Importa las pantallas de tu compañero (cuando las tenga listas)
// import 'screens/onboarding_screen.dart';
// import 'screens/home_screen.dart';
// import 'screens/glucose_screen.dart';
// import 'screens/pressure_screen.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_URL',
    defaultValue: LocalConfig.supabaseUrl,
  ),
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: LocalConfig.supabaseAnonKey,
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw Exception(
      'Faltan variables de Supabase. '
      'Usa --dart-define=NEXT_PUBLIC_SUPABASE_URL=... '
      '--dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=... '
      'o configura lib/core/local_config.dart',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );

  runApp(const ClinikApp());
}

class ClinikApp extends StatelessWidget {
  const ClinikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CLINIK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        fontFamily: 'sans-serif',
      ),
      home: const SplashScreen(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const MainWrapperScreen(),
        '/medical-followup': (context) => const MedicalFollowupScreen(),
        '/day-summary': (context) => const NutritionScoreScreen(),
      },
    );
  }
}

/// Contenedor Principal con BottomNavigationBar activa
class MainWrapperScreen extends StatefulWidget {
  final int initialIndex;
  const MainWrapperScreen({super.key, this.initialIndex = 0});

  @override
  State<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends State<MainWrapperScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // Construye solo la pestaña activa para evitar cargar 4 pantallas completas al entrar.
  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const RecordsScreen();
      case 2:
        return const MedicationsScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: MainBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}