import 'package:clinik/widgets/medical_chat_floating_button.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  int _selectedMetric = 0; // 0: Glucosa, 1: Presión arterial
  int _selectedPeriod = 0; // 0: 7 días, 1: 30 días, 2: 3 meses

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const MedicalChatFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER PERFIL & NOTIFICACIONES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'CLINIK',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Mis registros',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.prussianBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined, size: 28),
                    onPressed: () => Navigator.pushNamed(context, '/medical-followup'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Subtítulo y Badge "Al día"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Evolución y seguimiento de tus constantes',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.aliceBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(radius: 3, backgroundColor: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Al día',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. TOGGLE DE MÉTRICA (GLUCOSA / PRESIÓN ARTERIAL)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.aliceBlue.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMetric = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedMetric == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedMetric == 0
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.water_drop_outlined,
                                size: 18,
                                color: _selectedMetric == 0 ? AppColors.primary : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Glucosa',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedMetric == 0 ? AppColors.primary : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMetric = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedMetric == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedMetric == 1
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.favorite_border,
                                size: 18,
                                color: _selectedMetric == 1 ? AppColors.primary : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Presión arterial',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedMetric == 1 ? AppColors.primary : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. FILTRO DE TEMPORALIDAD
              Row(
                children: [
                  _buildPeriodChip('7 días', 0),
                  const SizedBox(width: 8),
                  _buildPeriodChip('30 días', 1),
                  const SizedBox(width: 8),
                  _buildPeriodChip('3 meses', 2),
                ],
              ),
              const SizedBox(height: 20),

              // 4. CARD DE TENDENCIA / GRÁFICA
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Glucosa · Últimos 7 días',
                          style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.stable.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.check_circle_outline, size: 14, color: AppColors.stable),
                              SizedBox(width: 4),
                              Text(
                                'Estable',
                                style: TextStyle(fontSize: 12, color: AppColors.stable, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Promedio principal
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: '106 ',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          TextSpan(
                            text: 'mg/dL prom.',
                            style: TextStyle(fontSize: 14, color: AppColors.prussianBlue, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Rango Saludable Objetivo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.aliceBlue.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Row(
                            children: [
                              Icon(Icons.check_box_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Rango saludable objetivo', style: TextStyle(fontSize: 12, color: AppColors.prussianBlue)),
                            ],
                          ),
                          Text(
                            '70 – 130 mg/dL',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Representación gráfica interactiva/visual
                    _buildChartVisualization(),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Última lectura: Hoy, 08:30', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Row(
                          children: [
                            Text(
                              '100% en meta ',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. CARD COMPACTO: PRESIÓN ARTERIAL (MÉTRICA SECUNDARIA)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.aliceBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.show_chart, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Presión arterial',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.stable.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Óptima',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.stable),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text('Último control · Ayer 19:40', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    RichText(
                      textAlign: TextAlign.end,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: '120 / 80\n',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                          ),
                          TextSpan(
                            text: 'mmHg (Sis / Dia)',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 6. REGISTROS RECIENTES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registros recientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Row(
                      children: const [
                        Text('Ver historial', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // LISTA DE REGISTROS
              _buildHistoryTile('105 mg/dL', 'Hoy · 08:30', 'En ayuno', 'En rango'),
              const SizedBox(height: 8),
              _buildHistoryTile('112 mg/dL', 'Ayer · 08:25', 'En ayuno', 'En rango'),
              const SizedBox(height: 8),
              _buildHistoryTile('108 mg/dL', '5 sep · 08:40', 'En ayuno', 'En rango'),

              const SizedBox(height: 20),

              // BOTÓN AÑADIR NUEVA MEDICIÓN
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.aliceBlue.withValues(alpha: 0.5),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  label: const Text(
                    'Añadir nueva medición',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para chips de período
  Widget _buildPeriodChip(String label, int index) {
    bool isSelected = _selectedPeriod == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedPeriod = index;
        });
      },
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.prussianBlue,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : Colors.black12),
      ),
      showCheckmark: isSelected,
      checkmarkColor: Colors.white,
    );
  }

  // Componente visual para la gráfica de puntos y curva
  Widget _buildChartVisualization() {
    final List<Map<String, dynamic>> points = [
      {'day': 'Lun', 'val': '98'},
      {'day': 'Mar', 'val': '105'},
      {'day': 'Mié', 'val': '112'},
      {'day': 'Jue', 'val': '101'},
      {'day': 'Vie', 'val': '108'},
      {'day': 'Sáb', 'val': '115'},
      {'day': 'Hoy', 'val': '105'},
    ];

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.aliceBlue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((p) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      p['val']!,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    const CircleAvatar(
                      radius: 4,
                      backgroundColor: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: points.map((p) {
              return Text(
                p['day']!,
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Item para lista de historial
  Widget _buildHistoryTile(String value, String date, String status, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.aliceBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Text(' · ', style: TextStyle(color: Colors.grey)),
                      Text(status, style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.stable.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 12, color: AppColors.stable),
                const SizedBox(width: 4),
                Text(
                  tag,
                  style: const TextStyle(fontSize: 11, color: AppColors.stable, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}