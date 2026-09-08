import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class NutritionScoreScreen extends StatefulWidget {
  const NutritionScoreScreen({super.key});

  @override
  State<NutritionScoreScreen> createState() => _NutritionScoreScreenState();
}

class _NutritionScoreScreenState extends State<NutritionScoreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scoreAnimation;

  final int _targetScore = 83; // Puntaje objetivo

  @override
  void initState() {
    super.initState();

    // Configuración del controlador de la animación (duración de 1.5 segundos)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Animación con curva suave (de 0 a _targetScore)
    _scoreAnimation = Tween<double>(
      begin: 0,
      end: _targetScore.toDouble(),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Inicia la animación en cuanto carga la pantalla
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.prussianBlue, size: 28),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Encabezado
              const Text(
                'Tu Score Nutricional',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sáb, 12 Sept',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),

              // Indicador Circular de Score ANIMADO
              AnimatedBuilder(
                animation: _scoreAnimation,
                builder: (context, child) {
                  return _buildScoreCircle(
                    score: _scoreAnimation.value.toInt(),
                    progress: _scoreAnimation.value / 100,
                    status: 'Bueno',
                  );
                },
              ),
              const SizedBox(height: 28),

              // Tarjeta de Feedback Clínico / Nutricional
              _buildFeedbackCard(
                title: 'Buen trabajo hoy',
                description:
                    'Tuviste un día sólido, pero la fibra y la vitamina C estuvieron bajas. Considera añadir más verduras de hoja verde y cítricos para mejorar.',
              ),
              const SizedBox(height: 28),

              // Sección de Nutrientes Principales
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nutrientes Principales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.prussianBlue,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildNutrientRow(
                icon: Icons.bolt,
                iconColor: Colors.amber.shade700,
                label: 'Calorías',
                status: 'Bajo',
                statusColor: Colors.orange,
                value: '1,581 / 1,766 kcal',
              ),
              const SizedBox(height: 12),

              _buildNutrientRow(
                icon: Icons.fitness_center,
                iconColor: AppColors.primary,
                label: 'Proteínas',
                status: 'En rango',
                statusColor: Colors.green,
                value: '115 / 127 g',
              ),
              const SizedBox(height: 12),

              _buildNutrientRow(
                icon: Icons.grain,
                iconColor: Colors.brown,
                label: 'Fibra',
                status: 'Bajo',
                statusColor: Colors.redAccent,
                value: '18 / 30 g',
              ),
              const SizedBox(height: 12),

              _buildNutrientRow(
                icon: Icons.opacity,
                iconColor: Colors.blue,
                label: 'Hidratación',
                status: 'Excelente',
                statusColor: Colors.green,
                value: '2.5 / 2.5 L',
              ),
              const SizedBox(height: 28),

              // Botón de Compartir / Confirmar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                  label: const Text(
                    'Compartir con mi Nutriólogo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para el indicador circular
  Widget _buildScoreCircle({
    required int score,
    required double progress,
    required String status,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 170,
          height: 170,
          child: CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 14,
            backgroundColor: Colors.black.withOpacity(0.06),
            color: Colors.green.shade600,
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: const TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.bold,
                color: AppColors.prussianBlue,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Tarjeta de recomendación
  Widget _buildFeedbackCard({required String title, required String description}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.prussianBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Ver más detalles',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fila individual de nutriente con estado
  Widget _buildNutrientRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String status,
    required Color statusColor,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.prussianBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
        ],
      ),
    );
  }
}