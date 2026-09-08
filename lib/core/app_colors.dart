import 'package:flutter/material.dart';

class AppColors {
  // 🎨 PALETA BASE SELECCIONADA
  
  /// Dark Cyan (#0D9488) - Color primario (Botones principales, marca, appbar)
  static const Color primary = Color(0xFF0D9488);
  
  /// Prussian Blue (#0F172A) - Texto principal, encabezados y fondo de cards oscuras
  static const Color prussianBlue = Color(0xFF0F172A);
  
  /// Bright Snow (#F8FAFC) - Fondo principal de las pantallas
  static const Color background = Color(0xFFF8FAFC);
  
  /// Alice Blue (#E0F2FE) - Contenedores secundarios, tarjetas o inputs destacados
  static const Color aliceBlue = Color(0xFFE0F2FE);

  // 🚦 SEMÁFORO DE ALERTAS MÉDICAS (Integrado)
  
  /// Estado Estable - Paciente dentro del rango normal
  static const Color stable = Color(0xFF10B981);
  
  /// Estado Advertencia / Falta de registro
  static const Color warning = Color(0xFFF59E0B);
  
  /// Estado Crítico / Riesgo descompensado
  static const Color critical = Color(0xFFEF4444);
}