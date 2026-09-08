import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class PatientActivityScreen extends StatefulWidget {
  const PatientActivityScreen({super.key});

  static int estimateCaloriesForExercise(String exerciseType, int durationMinutes) {
    final normalizedType = exerciseType.trim();
    final minutes = durationMinutes <= 0 ? 0 : durationMinutes;

    final factor = switch (normalizedType.toLowerCase()) {
      'caminata' => 3.125,
      'caminata rápida' => 4.2,
      'correr' => 12.5,
      'ciclismo' => 7.6,
      'gimnasio' || 'pesas' => 6.2,
      'bailar' || 'zumba' => 5.6,
      'estiramientos' || 'yoga' => 2.4,
      _ => 4.0,
    };

    return (factor * minutes).round();
  }

  @override
  State<PatientActivityScreen> createState() => _PatientActivityScreenState();
}

class _PatientActivityScreenState extends State<PatientActivityScreen> {
  // Simulación de actividades registradas en el día
  final List<LoggedActivity> _loggedActivities = [
    LoggedActivity(
      title: 'Caminata a buen ritmo',
      category: 'Caminata',
      durationMinutes: 30,
      caloriesBurned: 135,
      timeAgo: '08:00 AM',
      icon: Icons.directions_walk,
      iconColor: Colors.orange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    int totalMinutes = _loggedActivities.fold(0, (sum, item) => sum + item.durationMinutes);
    int totalCalories = _loggedActivities.fold(0, (sum, item) => sum + item.caloriesBurned);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Actividad Física',
          style: TextStyle(color: AppColors.prussianBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.prussianBlue),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Banner Principal de Registro Rápido (Basado en la imagen)
              _buildQuickRegisterCard(context),
              const SizedBox(height: 20),

              // 2. Tarjeta de Resumen del Día
              _buildDailyActivitySummary(totalMinutes, totalCalories),
              const SizedBox(height: 24),

              // 3. Recomendaciones de Actividad Física
              const Text(
                'Sugerencias para Hoy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mantente activo con metas sencillas adaptadas a tu plan',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 14),

              _buildRecommendationsGrid(),
              const SizedBox(height: 28),

              // 4. Registro del Día
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Actividades de Hoy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  Text(
                    '${_loggedActivities.length} registradas',
                    style: const TextStyle(fontSize: 13, color: Colors.black45),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_loggedActivities.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _loggedActivities.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _loggedActivities[index];
                    return _buildActivityTile(item);
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Tarjeta interactiva basada en la imagen del usuario
  Widget _buildQuickRegisterCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFADF), // Fondo amarillo suave de la imagen
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_run,
              color: Color(0xFFD48B00), // Ícono dorado/naranja de la imagen
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar actividad',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.prussianBlue,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Caminata, paseo o ejercicio físico',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 24),
              onPressed: () => _showAddActivityModal(context),
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta de progreso diario
  Widget _buildDailyActivitySummary(int minutes, int calories) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryMetric(
            icon: Icons.timer_outlined,
            iconColor: Colors.blue,
            value: '$minutes / 45',
            unit: 'minutos',
            label: 'Tiempo activo',
          ),
          Container(height: 35, width: 1, color: Colors.grey.shade200),
          _buildSummaryMetric(
            icon: Icons.local_fire_department_outlined,
            iconColor: Colors.deepOrange,
            value: '$calories',
            unit: 'kcal',
            label: 'Gasto estimado',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.prussianBlue,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  // Grid de Recomendaciones Generales
  Widget _buildRecommendationsGrid() {
    final suggestions = [
      {
        'title': 'Caminata Ligera',
        'desc': '30 min • Ritmo suave',
        'icon': Icons.directions_walk,
        'color': Colors.orange,
      },
      {
        'title': 'Bailar en casa',
        'desc': '20 min • Cardio divertido',
        'icon': Icons.music_note_outlined,
        'color': Colors.purple,
      },
      {
        'title': 'Gimnasio / Pesas',
        'desc': '45 min • Rutina de fuerza',
        'icon': Icons.fitness_center,
        'color': Colors.blue,
      },
      {
        'title': 'Estiramientos',
        'desc': '15 min • Movilidad y relax',
        'icon': Icons.self_improvement,
        'color': Colors.teal,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        final color = item['color'] as Color;

        return InkWell(
          onTap: () => _showAddActivityModal(context, defaultTitle: item['title'] as String),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item['icon'] as IconData, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.prussianBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['desc'] as String,
                        style: const TextStyle(fontSize: 10, color: Colors.black45),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ListTile para las actividades registradas
  Widget _buildActivityTile(LoggedActivity item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.prussianBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.durationMinutes} min  •  ${item.caloriesBurned} kcal  •  ${item.timeAgo}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: const Column(
        children: [
          Icon(Icons.directions_run_outlined, size: 40, color: Colors.black26),
          SizedBox(height: 8),
          Text(
            'No has registrado actividad hoy',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // Bottom Sheet Modal para agregar un nuevo registro
  void _showAddActivityModal(BuildContext context, {String? defaultTitle}) {
    final exerciseOptions = [
      'Caminata',
      'Caminata rápida',
      'Correr',
      'Ciclismo',
      'Gimnasio',
      'Bailar',
      'Estiramientos',
      'Yoga',
    ];

    final activityController = TextEditingController(text: defaultTitle ?? 'Caminata');
    final durationController = TextEditingController(text: defaultTitle != null ? '30' : '20');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final exerciseType = activityController.text.isNotEmpty
                ? activityController.text
                : exerciseOptions.first;
            final duration = int.tryParse(durationController.text) ?? 0;
            final estimatedCalories = PatientActivityScreen.estimateCaloriesForExercise(
              exerciseType,
              duration,
            );

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registrar Actividad',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: exerciseOptions.contains(exerciseType) ? exerciseType : exerciseOptions.first,
                    decoration: InputDecoration(
                      labelText: 'Tipo de ejercicio',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: exerciseOptions
                        .map(
                          (exercise) => DropdownMenuItem<String>(
                            value: exercise,
                            child: Text(exercise),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        activityController.text = value;
                        setModalState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Duración (min)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          enabled: false,
                          initialValue: '$estimatedCalories kcal',
                          decoration: InputDecoration(
                            labelText: 'Calorías estimadas',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final minutes = int.tryParse(durationController.text) ?? 0;
                        if (minutes <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ingresa una duración válida en minutos.'),
                            ),
                          );
                          return;
                        }

                        final title = activityController.text.trim().isNotEmpty
                            ? activityController.text.trim()
                            : 'Actividad física';

                        final calories = PatientActivityScreen.estimateCaloriesForExercise(
                          title,
                          minutes,
                        );

                        setState(() {
                          _loggedActivities.insert(
                            0,
                            LoggedActivity(
                              title: title,
                              category: title,
                              durationMinutes: minutes,
                              caloriesBurned: calories,
                              timeAgo: 'Ahora',
                              icon: Icons.directions_run,
                              iconColor: Colors.orange,
                            ),
                          );
                        });
                        Navigator.pop(modalContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Guardar Registro',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class LoggedActivity {
  final String title;
  final String category;
  final int durationMinutes;
  final int caloriesBurned;
  final String timeAgo;
  final IconData icon;
  final Color iconColor;

  LoggedActivity({
    required this.title,
    required this.category,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.timeAgo,
    required this.icon,
    required this.iconColor,
  });
}