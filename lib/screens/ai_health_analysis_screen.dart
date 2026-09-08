import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class AiHealthAnalysisScreen extends StatelessWidget {
  const AiHealthAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.prussianBlue),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Asistente IA',
          style: TextStyle(
            color: AppColors.prussianBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF134E4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Analisis generado con la informacion disponible',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Estado general favorable con buen apego al tratamiento.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'La informacion actual sugiere control estable de glucosa y presion, sin alertas inmediatas.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: 'Resumen del paciente',
                child: Column(
                  children: const [
                    _AnalysisMetricRow(
                      label: 'Glucosa reciente',
                      value: '105 mg/dL',
                      tone: Color(0xFF15803D),
                    ),
                    SizedBox(height: 10),
                    _AnalysisMetricRow(
                      label: 'Presion arterial',
                      value: '120/80 mmHg',
                      tone: AppColors.primary,
                    ),
                    SizedBox(height: 10),
                    _AnalysisMetricRow(
                      label: 'Adherencia nutricional',
                      value: '89% cumplido',
                      tone: Color(0xFFCA8A04),
                    ),
                    SizedBox(height: 10),
                    _AnalysisMetricRow(
                      label: 'Tratamiento registrado',
                      value: 'Metformina tomada',
                      tone: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Interpretacion de la IA',
                child: Column(
                  children: const [
                    _InsightTile(
                      icon: Icons.check_circle_outline,
                      iconColor: AppColors.stable,
                      title: 'Control metabolico estable',
                      description:
                          'La glucosa reportada se encuentra dentro de un rango compatible con buen control diario y sin evidencia de descompensacion aguda.',
                    ),
                    SizedBox(height: 12),
                    _InsightTile(
                      icon: Icons.favorite_border,
                      iconColor: AppColors.primary,
                      title: 'Presion arterial adecuada',
                      description:
                          'El valor 120/80 mmHg es consistente con una lectura optima, lo que reduce el riesgo inmediato de complicaciones cardiovasculares.',
                    ),
                    SizedBox(height: 12),
                    _InsightTile(
                      icon: Icons.medication_outlined,
                      iconColor: Color(0xFF2563EB),
                      title: 'Buen apego terapeutico',
                      description:
                          'El registro de medicamento tomado y la actividad reciente indican continuidad en el plan de seguimiento del paciente.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Por que la IA te dice esto',
                child: Column(
                  children: const [
                    _ReasonRow(
                      label: 'Glucosa en rango',
                      description: 'Porque 105 mg/dL no sugiere hiperglucemia marcada en la lectura mostrada.',
                    ),
                    SizedBox(height: 10),
                    _ReasonRow(
                      label: 'Presion sin alerta',
                      description: 'Porque 120/80 mmHg coincide con un valor meta frecuente en seguimiento clinico.',
                    ),
                    SizedBox(height: 10),
                    _ReasonRow(
                      label: 'Adherencia aceptable',
                      description: 'Porque el paciente ya completo registros clave del dia y mantiene seguimiento continuo.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Recomendaciones sugeridas',
                child: Column(
                  children: const [
                    _RecommendationTile(
                      number: '1',
                      title: 'Mantener la medicion nocturna',
                      description: 'Registrar la lectura de la noche ayudara a confirmar si el control se mantiene estable durante todo el dia.',
                    ),
                    SizedBox(height: 12),
                    _RecommendationTile(
                      number: '2',
                      title: 'Cuidar hidratacion y cena',
                      description: 'Una cena equilibrada y completar el objetivo de agua puede mejorar el score nutricional final.',
                    ),
                    SizedBox(height: 12),
                    _RecommendationTile(
                      number: '3',
                      title: 'Sostener actividad ligera',
                      description: 'Una caminata breve despues de comer puede apoyar el control glucemico y cardiovascular.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFB45309), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Este analisis es orientativo y se basa en la informacion disponible en la app. No sustituye la valoracion de tu medico o nutriologo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.prussianBlue,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AnalysisMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color tone;

  const _AnalysisMetricRow({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _InsightTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String label;
  final String description;

  const _ReasonRow({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.prussianBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _RecommendationTile({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}