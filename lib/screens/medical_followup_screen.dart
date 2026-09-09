import 'package:clinik/screens/medications_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_colors.dart';

class MedicalFollowupScreen extends StatefulWidget {
  const MedicalFollowupScreen({super.key});

  @override
  State<MedicalFollowupScreen> createState() => _MedicalFollowupScreenState();
}

class _MedicalFollowupScreenState extends State<MedicalFollowupScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _loadError;
  Map<String, dynamic>? _perfil;
  dynamic _patientId;
  List<_TreatmentFollowupItem> _items = <_TreatmentFollowupItem>[];

  @override
  void initState() {
    super.initState();
    _loadFollowupData();
  }

  Future<void> _loadFollowupData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _loadError = 'No hay una sesión activa.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final paciente = await _supabase
          .from('pacientes')
          .select('id_paciente')
          .eq('id_usuario', userId)
          .maybeSingle();

      final patientId = paciente?['id_paciente'];
      final perfilFuture = _supabase
          .from('perfiles')
          .select()
          .eq('id_usuario', userId)
          .maybeSingle();
      final itemsFuture = patientId == null
          ? Future.value(<_TreatmentFollowupItem>[])
          : _loadTreatmentItems(patientId);

      final results = await Future.wait<dynamic>([perfilFuture, itemsFuture]);

      if (!mounted) return;
      setState(() {
        _perfil = results[0] as Map<String, dynamic>?;
        _patientId = patientId;
        _items = results[1] as List<_TreatmentFollowupItem>;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error al cargar seguimiento médico: $error');
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudo cargar tu seguimiento médico.';
        _isLoading = false;
      });
    }
  }

  Future<List<_TreatmentFollowupItem>> _loadTreatmentItems(dynamic patientId) async {
    final candidates = <dynamic>{patientId};
    final asText = patientId.toString().trim();
    if (asText.isNotEmpty) {
      candidates.add(asText);
      final asInt = int.tryParse(asText);
      if (asInt != null) {
        candidates.add(asInt);
      }
    }

    List<dynamic> rows = <dynamic>[];
    for (final candidate in candidates) {
      try {
        final data = await _supabase
            .from('tratamientos')
            .select('*')
            .eq('id_paciente', candidate)
            .eq('estado', 'activo')
            .order('fecha_inicio', ascending: false);
        if (data is List && data.isNotEmpty) {
          rows = data;
          break;
        }
      } catch (_) {
        // Sigue intentando con otra variante del identificador.
      }
    }

    final items = rows
        .whereType<Map<String, dynamic>>()
        .map(_TreatmentFollowupItem.fromRow)
        .where((item) => item.medicineName.isNotEmpty)
        .toList();

    items.sort((left, right) {
      if (left.isOverdue != right.isOverdue) {
        return left.isOverdue ? -1 : 1;
      }
      return left.sortMinutes.compareTo(right.sortMinutes);
    });

    return items;
  }

  String get _patientName {
    final parts = <String>[
      _asString(_perfil?['nombre']) ?? '',
      _asString(_perfil?['apellido_paterno']) ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Paciente' : parts.join(' ');
  }

  int get _pendingCount => _items.where((item) => item.isPending).length;

  int get _completedCount => _items.where((item) => item.isTaken).length;

  double get _adherenceRatio {
    final total = _items.length;
    if (total == 0) return 0;
    return _completedCount / total;
  }

  String get _headerSubtitle {
    if (_items.isEmpty) {
      return 'Mantener al día tus tratamientos ayuda a tu equipo a revisar tu dosis y horario.';
    }
    final nextItem = _items.firstWhere(
      (item) => item.isPending,
      orElse: () => _items.first,
    );
    return 'Siguiente toma: ${nextItem.medicineName} · ${nextItem.timeLabel}';
  }

  String get _lastUpdateLabel {
    if (_items.isEmpty) return 'Sin registros recientes';
    final latest = _items.first;
    return 'Último seguimiento: ${latest.dateLabel}';
  }

  String? _asString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

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
        child: RefreshIndicator(
          onRefresh: _loadFollowupData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  _headerSubtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 20),
                if (_loadError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      _loadError!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
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
                        'Necesitamos revisar tus tratamientos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.prussianBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _lastUpdateLabel,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
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
                            _buildStatusRow(Icons.calendar_today_outlined, 'Último tratamiento', _items.isEmpty ? 'Sin datos' : _items.first.dateLabel),
                            const Divider(height: 12),
                            _buildStatusRowWithBadge(Icons.medication_outlined, 'Medicamentos pendientes', '$_pendingCount pendientes'),
                            const Divider(height: 12),
                            _buildStatusRow(Icons.schedule_outlined, 'Horario activo', _items.isEmpty ? 'Sin horario' : _items.first.timeLabel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                  subtitle: 'Confirmar dosis y horario de hoy',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MedicationsScreen()),
                  ),
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
                                  'Ahora el panel toma dosis, frecuencia y horario desde tratamientos reales.',
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
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.critical),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tu médico puede revisar el tratamiento completo con dosis y frecuencia desde la tabla de tratamientos sincronizada.',
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
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MedicationsScreen()),
                          ),
                          icon: const Icon(Icons.medication_outlined, color: Colors.white, size: 18),
                          label: const Text(
                            'Ver medicamentos con horario y dosis',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
      ),
    );
  }

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

class _TreatmentFollowupItem {
  _TreatmentFollowupItem({
    required this.medicineName,
    required this.doseLabel,
    required this.frequencyLabel,
    required this.timeLabel,
    required this.dateLabel,
    required this.statusLabel,
    required this.isTaken,
    required this.isPending,
    required this.isOverdue,
    required this.sortMinutes,
  });

  final String medicineName;
  final String doseLabel;
  final String frequencyLabel;
  final String timeLabel;
  final String dateLabel;
  final String statusLabel;
  final bool isTaken;
  final bool isPending;
  final bool isOverdue;
  final int sortMinutes;

  factory _TreatmentFollowupItem.fromRow(Map<String, dynamic> row) {
    final medicineName = _pickString(row, <String>[
          'nombre_medicamento',
          'medicamento',
          'nombre',
        ]) ??
        'Medicamento';
    final dose = _pickString(row, <String>['dosis', 'dosis_indicada']) ?? 'Sin dosis';
    final frequency = _pickString(row, <String>['frecuencia']) ?? 'Sin frecuencia';
    final administration = _pickString(row, <String>['via_administracion', 'via']) ?? 'Oral';
    final startedAt = _pickString(row, <String>['fecha_inicio']);
    final statusRaw = (_pickString(row, <String>['estado']) ?? '').toLowerCase();
    final takenRaw = (_pickString(row, <String>['estado_toma']) ?? '').toLowerCase();

    final timeLabel = _frequencyToTimeLabel(frequency);
    final sortMinutes = _frequencyToMinutes(frequency);
    final isTaken = takenRaw.contains('tomad') || statusRaw.contains('tomad');
    final isPending = !isTaken && _isDueNow(sortMinutes, frequency);
    final isOverdue = !isTaken && !isPending && sortMinutes < 24 * 60;

    final parts = <String>[
      dose,
      if (administration.isNotEmpty) administration,
      if (frequency.isNotEmpty) frequency,
    ];

    return _TreatmentFollowupItem(
      medicineName: medicineName,
      doseLabel: parts.join(' · '),
      frequencyLabel: frequency,
      timeLabel: timeLabel,
      dateLabel: startedAt == null ? 'Sin fecha' : _formatDateLabel(startedAt),
      statusLabel: isTaken ? 'Tomada' : (isPending ? 'Pendiente' : 'Programada'),
      isTaken: isTaken,
      isPending: isPending,
      isOverdue: isOverdue,
      sortMinutes: sortMinutes,
    );
  }

  static String? _pickString(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static int _frequencyToMinutes(String frequency) {
    final normalized = frequency.toLowerCase();
    final everyMatch = RegExp(r'cada\s+(\d+)\s+hora').firstMatch(normalized);
    if (everyMatch != null) {
      final hours = int.tryParse(everyMatch.group(1) ?? '') ?? 24;
      return hours * 60;
    }

    if (normalized.contains('12 horas')) return 12 * 60;
    if (normalized.contains('8 horas')) return 8 * 60;
    if (normalized.contains('24 horas')) return 24 * 60;
    return 24 * 60;
  }

  static String _frequencyToTimeLabel(String frequency) {
    final normalized = frequency.toLowerCase();
    if (normalized.contains('cada 12')) return '08:00 hrs';
    if (normalized.contains('cada 24')) return '08:00 hrs';
    if (normalized.contains('cada 8')) return '06:00 hrs';
    return 'Horario no definido';
  }

  static String _formatDateLabel(String rawDate) {
    final date = DateTime.tryParse(rawDate)?.toLocal();
    if (date == null) return rawDate;
    return '${date.day}/${date.month}/${date.year}';
  }

  static bool _isDueNow(int sortMinutes, String frequency) {
    final now = TimeOfDay.now();
    final currentMinutes = (now.hour * 60) + now.minute;
    if (sortMinutes >= 24 * 60) return false;
    final normalized = frequency.toLowerCase();
    if (normalized.contains('cada 24')) {
      return currentMinutes >= 7 * 60 && currentMinutes <= 10 * 60;
    }
    if (normalized.contains('cada 12')) {
      return currentMinutes >= 7 * 60 && currentMinutes <= 10 * 60 ||
          currentMinutes >= 19 * 60 && currentMinutes <= 22 * 60;
    }
    return (currentMinutes - sortMinutes).abs() <= 90;
  }
}
