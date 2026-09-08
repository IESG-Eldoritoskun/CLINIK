import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';

class RegisterPressureScreen extends StatefulWidget {
  const RegisterPressureScreen({super.key});

  @override
  State<RegisterPressureScreen> createState() => _RegisterPressureScreenState();
}

class _RegisterPressureScreenState extends State<RegisterPressureScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _systolic = 120;
  int _diastolic = 80;
  int _pulse = 72;
  bool _isSaving = false;

  Future<void> _savePressureReading() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No hay sesión activa para guardar la presión.');
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

      await _supabase.from('presiones_arteriales').insert({
        'id_paciente': pacienteId,
        'sistolica': _systolic,
        'diastolica': _diastolic,
        'frecuencia': _pulse,
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
            content: Text('No se pudo guardar la presión: $error'),
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

  void _adjustVal(String type, int delta) {
    setState(() {
      if (type == 'sys') {
        final newVal = _systolic + delta;
        if (newVal >= 50 && newVal <= 250) _systolic = newVal;
      } else if (type == 'dia') {
        final newVal = _diastolic + delta;
        if (newVal >= 30 && newVal <= 150) _diastolic = newVal;
      } else if (type == 'pulse') {
        final newVal = _pulse + delta;
        if (newVal >= 35 && newVal <= 200) _pulse = newVal;
      }
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
                  'Tu presión arterial fue registrada correctamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 20),

                // Resumen dinámico de las 3 métricas
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.aliceBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Sistólica
                      Column(
                        children: [
                          const Text(
                            'Sistólica',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          Text(
                            '$_systolic',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'mmHg',
                            style: TextStyle(fontSize: 10, color: Colors.black45),
                          ),
                        ],
                      ),
                      Container(height: 32, width: 1, color: Colors.black12),
                      // Diastólica
                      Column(
                        children: [
                          const Text(
                            'Diastólica',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          Text(
                            '$_diastolic',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.prussianBlue,
                            ),
                          ),
                          const Text(
                            'mmHg',
                            style: TextStyle(fontSize: 10, color: Colors.black45),
                          ),
                        ],
                      ),
                      Container(height: 32, width: 1, color: Colors.black12),
                      // Pulso
                      Column(
                        children: [
                          const Text(
                            'Pulso',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          Text(
                            '$_pulse',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.prussianBlue,
                            ),
                          ),
                          const Text(
                            'lpm',
                            style: TextStyle(fontSize: 10, color: Colors.black45),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botón Volver al inicio
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
                      Navigator.pop(context); // Vuelve a Home
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
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: const Text(
          'Registrar presión',
          style: TextStyle(
            color: AppColors.prussianBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.favorite, color: AppColors.primary, size: 24),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título y Subtítulo
              const Text(
                'Registra tu presión',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Introduce los valores que aparecen en tu monitor.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 20),

              // Bloque Presión Sistólica (Alta)
              _buildPressureCard(
                title: 'Presión Sistólica',
                badgeText: 'Alta',
                badgeColor: AppColors.primary,
                value: _systolic,
                unit: 'mmHg',
                subtitle: 'Primer número en la pantalla del tensiómetro (SYS)',
                onDecrement: () => _adjustVal('sys', -1),
                onIncrement: () => _adjustVal('sys', 1),
                primaryColor: AppColors.primary,
              ),
              const SizedBox(height: 16),

              // Bloque Presión Diastólica (Baja)
              _buildPressureCard(
                title: 'Presión Diastólica',
                badgeText: 'Baja',
                badgeColor: AppColors.prussianBlue,
                value: _diastolic,
                unit: 'mmHg',
                subtitle: 'Segundo número en la pantalla del tensiómetro (DIA)',
                onDecrement: () => _adjustVal('dia', -1),
                onIncrement: () => _adjustVal('dia', 1),
                primaryColor: AppColors.prussianBlue,
              ),
              const SizedBox(height: 16),

              // Bloque Frecuencia Cardíaca (Opcional)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.monitor_heart_outlined, color: AppColors.primary, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Frecuencia cardíaca',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.prussianBlue,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Opcional',
                          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _adjustVal('pulse', -1),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.aliceBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.remove, color: AppColors.prussianBlue, size: 22),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$_pulse',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.prussianBlue,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'lpm',
                                  style: TextStyle(fontSize: 13, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _adjustVal('pulse', 1),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.aliceBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, color: AppColors.prussianBlue, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tarjeta Informativa Amigable
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.aliceBlue,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.prussianBlue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Seguimiento compartido',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tu equipo de salud podrá ver estos registros para darte seguimiento continuo y personalizado.',
                            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botón Principal de Guardado
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
                  onPressed: _isSaving ? null : _savePressureReading,
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
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
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

  // Widget auxiliar para las tarjetas principales de Sistólica y Diastólica
  Widget _buildPressureCard({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required int value,
    required String unit,
    required String subtitle,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 122, 100, 0.04),
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
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.aliceBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Botón Disminuir
              InkWell(
                onTap: onDecrement,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.aliceBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.remove, color: primaryColor, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              // Caja con el valor
              Expanded(
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'mmHg',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Botón Incrementar
              InkWell(
                onTap: onIncrement,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.aliceBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.add, color: primaryColor, size: 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}