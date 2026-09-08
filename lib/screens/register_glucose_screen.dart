import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';

class RegisterGlucoseScreen extends StatefulWidget {
  const RegisterGlucoseScreen({super.key});

  @override
  State<RegisterGlucoseScreen> createState() => _RegisterGlucoseScreenState();
}

class _RegisterGlucoseScreenState extends State<RegisterGlucoseScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _glucoseValue = 105;
  String _selectedContext = 'ayuno'; // 'ayuno', 'post', 'otro'
  int _selectedMood = 0; // 0: Bien, 1: Regular, 2: Mal
  bool _isSaving = false;

  Future<void> _saveGlucoseReading() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No hay sesión activa para guardar la glucosa.');
      }

      final paciente = await _supabase
          .from('pacientes')
          .select('id_paciente')
          .eq('id_usuario', userId)
          .maybeSingle();

      final pacienteId = paciente?['id_paciente'];
      if (pacienteId == null) {
        throw Exception('No se encontró el paciente asociado a tu cuenta.');
      }

      await _supabase.from('mediciones').insert({
        'id_paciente': pacienteId,
        'tipo': 'glucosa',
        'valor': _glucoseValue,
        'unidad': 'mg/dL',
        'fecha': DateTime.now().toUtc().toIso8601String(),
        'origen': 'manual',
      });

      if (mounted) {
        _showSuccessModal();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar la glucosa: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _incrementGlucose() {
    setState(() {
      if (_glucoseValue < 500) _glucoseValue++;
    });
  }

  void _decrementGlucose() {
    setState(() {
      if (_glucoseValue > 40) _glucoseValue--;
    });
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono grande de confirmación
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.prussianBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Registro guardado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.prussianBlue,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tu medición se agregó correctamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 20),

                // Resumen del valor
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.aliceBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Valor registrado',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      Text(
                        '$_glucoseValue mg/dL',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botón volver
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Cierra el modal
                      Navigator.pop(
                        context,
                      ); // Vuelve a la pantalla anterior (Home)
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.home, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Volver al inicio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          label: const Text(
            'Volver',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: const Text(
          'Registrar glucosa',
          style: TextStyle(
            color: AppColors.prussianBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado empático
              const Text(
                '¿Cuál es tu nivel de glucosa?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ingresa la medición actual que obtuviste en tu glucómetro.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 20),

              // Tarjeta principal de entrada de métrica
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 122, 100, 0.05),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Botón Decrementar (-)
                        InkWell(
                          onTap: _decrementGlucose,
                          borderRadius: BorderRadius.circular(27),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              color: AppColors.aliceBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.remove,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        ),

                        // Display del Valor
                        Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$_glucoseValue',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'mg/dL',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Indicador de rango
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.aliceBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Rango habitual saludable',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Botón Incrementar (+)
                        InkWell(
                          onTap: _incrementGlucose,
                          borderRadius: BorderRadius.circular(27),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              color: AppColors.aliceBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 12),

                    // Valores Rápidos (Presets)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [90, 105, 120, 140].map((val) {
                        final isSelected = _glucoseValue == val;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _glucoseValue = val;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.aliceBlue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$val',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.prussianBlue,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Selector de Contexto (¿Cuándo la mediste?)
              const Text(
                '¿Cuándo la mediste?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 12),

              _buildContextOption(
                keyName: 'ayuno',
                icon: Icons.wb_sunny_outlined,
                title: 'Antes de comer (ayuno)',
              ),
              const SizedBox(height: 8),
              _buildContextOption(
                keyName: 'post',
                icon: Icons.restaurant_outlined,
                title: 'Después de comer',
              ),
              const SizedBox(height: 8),
              _buildContextOption(
                keyName: 'otro',
                icon: Icons.schedule_outlined,
                title: 'Otro momento',
              ),
              const SizedBox(height: 24),

              // Selector Opcional de Estado de Ánimo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    '¿Cómo te sientes?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  Text(
                    'Opcional',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildMoodOption(
                      index: 0,
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      label: 'Bien',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMoodOption(
                      index: 1,
                      icon: Icons.sentiment_neutral_rounded,
                      label: 'Regular',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMoodOption(
                      index: 2,
                      icon: Icons.sentiment_dissatisfied_rounded,
                      label: 'Mal',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Botón Guardar Registro
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isSaving ? null : _saveGlucoseReading,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.8,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.save_outlined, color: Colors.white, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Guardar registro',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
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

  // Widget auxiliar para opciones de contexto (radios estilizados)
  Widget _buildContextOption({
    required String keyName,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _selectedContext == keyName;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedContext = keyName;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.black.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.prussianBlue,
                  ),
                ),
              ],
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para selección de Estado de Ánimo
  Widget _buildMoodOption({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedMood == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMood = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.black.withValues(alpha: 0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? Colors.white : AppColors.prussianBlue,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.prussianBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
