import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'nutrition_score_screen.dart';

class PatientNutritionScreen extends StatefulWidget {
  const PatientNutritionScreen({super.key});

  @override
  State<PatientNutritionScreen> createState() => _PatientNutritionScreenState();
}

class _PatientNutritionScreenState extends State<PatientNutritionScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Diario de Alimentación',
          style: TextStyle(color: AppColors.prussianBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.prussianBlue),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: AppColors.prussianBlue),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Selector Semanal de Fechas
              _buildDateSelector(),
              const SizedBox(height: 20),

              // 2. Resumen Clínico / Plan Nutricional del Día + Botón de Terminar Día
              _buildDailyNutritionSummary(),
              const SizedBox(height: 20),

              // 3. Control de Hidratación
              _buildWaterTracker(),
              const SizedBox(height: 24),

              // 4. Secciones de Comidas
              _buildMealSection(
                mealName: 'Desayuno',
                time: '08:30 AM',
                calories: 471,
                protein: '22g',
                carbs: '52g',
                fat: '21g',
                isCompleted: true,
                items: [
                  MealItemModel(name: 'Plátano', portion: '1 unidad (130g)', calories: '116 kcal', isPrescribed: true),
                  MealItemModel(name: 'Huevo entero', portion: '2 piezas (110g)', calories: '157 kcal', isPrescribed: true),
                  MealItemModel(name: 'Tortilla de maíz', portion: '1 unidad (40g)', calories: '119 kcal', isPrescribed: true),
                  MealItemModel(name: 'Cacahuate', portion: '1 cucharada (14g)', calories: '79 kcal', isPrescribed: false),
                ],
              ),
              const SizedBox(height: 16),

              _buildMealSection(
                mealName: 'Comida / Almuerzo',
                time: '02:00 PM',
                calories: 620,
                protein: '42g',
                carbs: '65g',
                fat: '18g',
                isCompleted: true,
                items: [
                  MealItemModel(name: 'Pechuga de pollo a la plancha', portion: '180g', calories: '295 kcal', isPrescribed: true),
                  MealItemModel(name: 'Arroz integral cocido', portion: '1 taza (150g)', calories: '215 kcal', isPrescribed: true),
                  MealItemModel(name: 'Ensalada verde mixta', portion: '1 plato (100g)', calories: '110 kcal', isPrescribed: true),
                ],
              ),
              const SizedBox(height: 16),

              _buildMealSection(
                mealName: 'Cena',
                time: '08:00 PM',
                calories: 320,
                protein: '18g',
                carbs: '22g',
                fat: '12g',
                isCompleted: false,
                items: [],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para la barra semanal de fechas
  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final dayDate = DateTime.now().add(Duration(days: index - 3));
          final isSelected = dayDate.day == _selectedDate.day;
          final daysShort = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = dayDate),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    daysShort[dayDate.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dayDate.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.prussianBlue,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // Tarjeta de resumen de calorías + Botón "Terminar Día"
  Widget _buildDailyNutritionSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan Prescrito',
                    style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '1,581 / 1,766 kcal',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '89% Cumplido',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: 1581 / 1766,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroProgress('Proteínas', '115 / 127 g', 115 / 127, AppColors.primary),
              _buildMacroProgress('Carbos', '139 / 182 g', 139 / 182, Colors.orange),
              _buildMacroProgress('Grasas', '63 / 59 g', 1.0, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 20),

          // --- BOTÓN PRINCIPAL "TERMINAR DÍA" ---
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NutritionScoreScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.task_alt_outlined, color: Colors.white, size: 20),
              label: const Text(
                'Score nutrucional',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.prussianBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroProgress(String label, String value, double progress, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.prussianBlue)),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // Tarjeta de Registro de Agua
  Widget _buildWaterTracker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hidratación',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                ),
                Text(
                  '1.5 / 2.5 Litros consumidos',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
          ),
        ],
      ),
    );
  }

  // Sección de tiempos de comida
  Widget _buildMealSection({
    required String mealName,
    required String time,
    required int calories,
    required String protein,
    required String carbs,
    required String fat,
    required bool isCompleted,
    required List<MealItemModel> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          mealName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($time)',
                          style: const TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🔥 $calories kcal  •  ${protein}P  ${carbs}C  ${fat}G',
                      style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  dense: true,
                  title: Row(
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.prussianBlue),
                      ),
                      if (item.isPrescribed) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 14, color: AppColors.primary),
                      ],
                    ],
                  ),
                  subtitle: Text(item.portion, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.calories, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        color: isCompleted ? Colors.green : Colors.grey.shade300,
                        size: 20,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class MealItemModel {
  final String name;
  final String portion;
  final String calories;
  final bool isPrescribed;

  MealItemModel({
    required this.name,
    required this.portion,
    required this.calories,
    required this.isPrescribed,
  });
}