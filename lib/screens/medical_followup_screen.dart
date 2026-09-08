import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class MedicalFollowupScreen extends StatelessWidget {
  const MedicalFollowupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Seguimiento médico',
          style: TextStyle(
            color: AppColors.prussianBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BADGE Y MENSAJE DE ENCABEZADO
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.aliceBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.favorite_outline, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Acompañamiento CLINIK',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cuidamos tus pasos día a día',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mantener al día tus mediciones permite a tu equipo en Morelia apoyarte de manera oportuna y personalizada.',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 20),

              // 1. CARD DE ALERTA AMARILLA: ATENCIÓN RECOMENDADA
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warning, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppColors.warning, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Atención recomendada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Necesitamos revisar tus registros',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hemos notado que faltan algunos registros recientes de esta semana.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),

                    // Cuadro de desglose interno
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ESTADO RECIENTE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          _buildStatusRow(Icons.calendar_today_outlined, 'Último registro', '4 de septiembre'),
                          const Divider(height: 12),
                          _buildStatusRowWithBadge(Icons.medication_outlined, 'Medicamentos pendientes', '2 pendientes'),
                          const Divider(height: 12),
                          _buildStatusRow(Icons.favorite_border, 'Última medición de presión', '4 de septiembre'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. SECCIÓN: ¿QUÉ PUEDES HACER?
              const Text(
                '¿Qué puedes hacer?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Acciones simples para volver a poner tu plan al día:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),

              _buildActionCard(
                icon: Icons.water_drop_outlined,
                iconBg: const Color(0xFFFFE4E6),
                iconColor: AppColors.critical,
                title: 'Registrar mi medición ahora',
                subtitle: 'Glucosa o presión arterial en 1 min',
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _buildActionCard(
                icon: Icons.medication_outlined,
                iconBg: AppColors.aliceBlue,
                iconColor: AppColors.primary,
                title: 'Revisar medicamentos pendientes',
                subtitle: 'Confirmar dosis tomadas hoy',
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _buildActionCard(
                icon: Icons.phone_outlined,
                iconBg: const Color(0xFFE0E7FF),
                iconColor: const Color(0xFF3730A3),
                title: 'Contactar a mi centro de salud (Morelia)',
                subtitle: 'Línea directa de enfermería y citas',
                onTap: () {},
              ),
              const SizedBox(height: 24),

              // 3. SECCIÓN MODO DEMOSTRATIVO (NIVEL CLÍNICO / ALERTA CRÍTICA)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MODO DEMOSTRATIVO · NIVEL CLÍNICO',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.critical.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Prioridad médica',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.critical),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.critical.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.help_outline, color: AppColors.critical, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tu equipo de salud necesita revisar tus registros',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.prussianBlue,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Algunos datos recientes requieren seguimiento con el médico asignado.',
                                style: TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, size: 16, color: AppColors.critical),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No estás solo: tu médico de cabecera revisará tus tendencias para ajustar tu dosis con total tranquilidad.',
                              style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.critical,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.location_on_outlined, color: Colors.white, size: 18),
                        label: const Text(
                          'Ver información de contacto médico',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // FOOTER INFORMATIVO LOCAL
              Center(
                child: Column(
                  children: const [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Red Asistencial Morelia Michoacán · CLINIK',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tus datos se transmiten de forma segura y\nencriptada a tu expediente clínico.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers para la lista de estado
  Widget _buildStatusRow(IconData icon, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.prussianBlue)),
      ],
    );
  }

  Widget _buildStatusRowWithBadge(IconData icon, String title, String badgeText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badgeText,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
          ),
        ),
      ],
    );
  }

  // Helper para tarjetas de acción interactiva
  Widget _buildActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}