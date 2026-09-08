import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Redirige automáticamente al onboarding después de 3 segundos.
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. HEADER SUPERIOR (CONEXIÓN SEGURA & HIPAA READY)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: AppColors.stable,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'CONEXIÓN SEGURA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.prussianBlue,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'HIPAA READY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. CONTENIDO CENTRAL
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ISOTIPO / LOGO DE LA APP
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 120,
                          height: 120,
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/clinik_logo.svg',
                            width: 90,
                            height: 90,
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 22,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 2.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // NOMBRE DE LA APP & MÁS (+)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'CLINIK',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.prussianBlue,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.add,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ESLOGAN
                    const Text(
                      'Tu salud, siempre acompañada.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.prussianBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CHIP "BIENESTAR INTELIGENTE & SERENO"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.aliceBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircleAvatar(
                            radius: 3.5,
                            backgroundColor: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Bienestar inteligente & sereno',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // INDICADOR DE CARGA (PROGRESS BAR)
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: AppColors.aliceBlue,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // SECCIÓN CUIDAMOS CONTIGO
                    const Text(
                      'Cuidamos contigo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Monitoreo inteligente continuo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. FOOTER (VERSIÓN & ACCESO CIFRADO)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Versión 3.2.0',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: CircleAvatar(radius: 2, backgroundColor: Colors.grey),
                  ),
                  Text(
                    'Acceso Cifrado',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}