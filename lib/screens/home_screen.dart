import 'package:clinik/screens/ai_health_analysis_screen.dart';
import 'package:clinik/screens/patient_activity_screen.dart';
import 'package:clinik/screens/register_glucose_screen.dart';
import 'package:clinik/screens/patient_nutrition_screen.dart';
import 'package:clinik/screens/register_pressure_screen.dart';
import 'package:clinik/widgets/medical_chat_floating_button.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static String formatMetricDisplay({
    required String type,
    required Map<String, dynamic> data,
  }) {
    switch (type) {
      case 'glucosa':
        final valor = _asNum(data['valor']) ?? _asNum(data['value']);
        return valor?.toStringAsFixed(valor.truncateToDouble() == valor ? 0 : 1) ?? '--';
      case 'presion':
        final sistolica = data['sistolica'] ?? data['systolic'];
        final diastolica = data['diastolica'] ?? data['diastolic'];
        if (sistolica == null || diastolica == null) {
          return '--/--';
        }
        return '$sistolica/$diastolica';
      default:
        return data['valor']?.toString() ?? '--';
    }
  }

  static num? _asNum(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _paciente;
  Map<String, dynamic>? _ultimaGlucosa;
  Map<String, dynamic>? _ultimaPresion;
  List<Map<String, dynamic>> _medicationReminders = <Map<String, dynamic>>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final paciente = await _supabase
          .from('pacientes')
          .select()
          .eq('id_usuario', userId)
          .maybeSingle();

      final pacienteId = paciente?['id_paciente'] as String?;

      final Future<Map<String, dynamic>?> perfilFuture = _supabase
          .from('perfiles')
          .select()
          .eq('id_usuario', userId)
          .maybeSingle()
          .then((value) => value);

      final Future<Map<String, dynamic>?> glucosaFuture = pacienteId == null
          ? Future.value(null)
          : _supabase
              .from('mediciones')
              .select()
              .eq('id_paciente', pacienteId)
              .eq('tipo', 'glucosa')
              .order('fecha', ascending: false)
              .limit(1)
              .maybeSingle()
              .then((value) => value);

      final Future<Map<String, dynamic>?> presionFuture = pacienteId == null
          ? Future.value(null)
          : _supabase
              .from('presiones_arteriales')
              .select()
              .eq('id_paciente', pacienteId)
              .order('fecha', ascending: false)
              .limit(1)
              .maybeSingle()
              .then((value) => value);

      final Future<List<Map<String, dynamic>>> remindersFuture = pacienteId == null
          ? Future.value(<Map<String, dynamic>>[])
          : _loadMedicationReminders(pacienteId);

      final List<Future<dynamic>> futures = [
        perfilFuture,
        glucosaFuture,
        presionFuture,
        remindersFuture,
      ];

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _perfil = results[0];
          _paciente = paciente;
          _ultimaGlucosa = results[1];
          _ultimaPresion = results[2];
          _medicationReminders = List<Map<String, dynamic>>.from(
            results[3] as List,
          );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String get _patientName {
    final nombre = (_perfil?['nombre'] as String?)?.trim();
    if (nombre != null && nombre.isNotEmpty) {
      return nombre;
    }
    return 'Paciente';
  }

  String get _emergencyContactLabel {
    final contactName =
        _asString(_paciente?['contacto_emergencia']) ??
        _asString(_paciente?['nombre_contacto_emergencia']) ??
        _asString(_paciente?['responsable_emergencia']);
    final contactPhone =
        _asString(_paciente?['telefono_contacto_emergencia']) ??
        _asString(_paciente?['telefono_emergencia']) ??
        _asString(_paciente?['celular_contacto_emergencia']);

    if (contactName != null && contactPhone != null) {
      return '$contactName · $contactPhone';
    }
    if (contactName != null) {
      return contactName;
    }
    if (contactPhone != null) {
      return contactPhone;
    }
    return 'No registrado';
  }

  String? _asString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _formatDateLabel(dynamic value) {
    if (value == null) return 'Sin registro';

    try {
      final date = DateTime.tryParse(value.toString());
      if (date == null) return 'Sin registro';

      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      if (isToday) {
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return 'Hoy, $hour:$minute';
      }

      return '${date.day}/${date.month}';
    } catch (_) {
      return 'Sin registro';
    }
  }

  String _getRangeStatus(String type, Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return 'Sin dato';
    }

    if (type == 'glucosa') {
      final valor = HomeScreen._asNum(data['valor']) ?? HomeScreen._asNum(data['value']);
      if (valor == null) return 'Sin dato';
      if (valor >= 70 && valor <= 140) return 'En rango';
      if (valor < 70) return 'Bajo';
      return 'Fuera de rango';
    }

    final sistolica = HomeScreen._asNum(data['sistolica']);
    final diastolica = HomeScreen._asNum(data['diastolica']);
    if (sistolica == null || diastolica == null) return 'Sin dato';
    if (sistolica <= 120 && diastolica <= 80) return 'Óptima';
    if (sistolica <= 129 && diastolica <= 84) return 'Buena';
    return 'Revisar';
  }

  Future<List<Map<String, dynamic>>> _loadMedicationReminders(
    dynamic patientId,
  ) async {
    final candidates = <dynamic>{patientId};
    final asText = patientId.toString().trim();
    if (asText.isNotEmpty) {
      candidates.add(asText);
      final asInt = int.tryParse(asText);
      if (asInt != null) {
        candidates.add(asInt);
      }
    }

    for (final candidate in candidates) {
      try {
        final data = await _supabase
            .from('vista_adherencia_tratamientos')
            .select(
              'id_tratamiento, medicamento, frecuencia, dosis_esperadas, dosis_tomadas, dosis_falladas, porcentaje_cumplimiento',
            )
            .eq('id_paciente', candidate)
            .limit(4);

        if (data.isNotEmpty) {
          final rows = List<Map<String, dynamic>>.from(data);
          rows.sort((a, b) {
            final missedA = _asInt(a['dosis_falladas']) ?? 0;
            final missedB = _asInt(b['dosis_falladas']) ?? 0;
            if (missedA != missedB) return missedB.compareTo(missedA);

            final expectedA = _asInt(a['dosis_esperadas']) ?? 0;
            final takenA = _asInt(a['dosis_tomadas']) ?? 0;
            final expectedB = _asInt(b['dosis_esperadas']) ?? 0;
            final takenB = _asInt(b['dosis_tomadas']) ?? 0;
            return (expectedB - takenB).compareTo(expectedA - takenA);
          });
          return rows.take(3).toList();
        }
      } catch (_) {
        // Intenta con la siguiente variación del id.
      }
    }

    return <Map<String, dynamic>>[];
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _reminderStatus(Map<String, dynamic> row) {
    final expected = _asInt(row['dosis_esperadas']) ?? 0;
    final taken = _asInt(row['dosis_tomadas']) ?? 0;
    final missed = _asInt(row['dosis_falladas']) ?? 0;
    final pending = (expected - taken).clamp(0, 999999);

    if (missed > 0) {
      return 'No tomadas: $missed';
    }
    if (pending > 0) {
      return 'Pendientes: $pending';
    }
    if (taken > 0) {
      return 'Tomadas: $taken';
    }
    return 'Sin tomas registradas';
  }

  _PatientTrafficState _buildPatientTrafficState() {
    final glucose = HomeScreen._asNum(_ultimaGlucosa?['valor']) ??
        HomeScreen._asNum(_ultimaGlucosa?['value']);
    final systolic = HomeScreen._asNum(_ultimaPresion?['sistolica']) ??
        HomeScreen._asNum(_ultimaPresion?['systolic']);
    final diastolic = HomeScreen._asNum(_ultimaPresion?['diastolica']) ??
        HomeScreen._asNum(_ultimaPresion?['diastolic']);

    final latestDates = <DateTime?>[
      _parseHomeDate(_ultimaGlucosa?['fecha']),
      _parseHomeDate(_ultimaPresion?['fecha']),
    ].whereType<DateTime>().toList();

    final latestDate = latestDates.isEmpty
        ? null
        : latestDates.reduce((a, b) => a.isAfter(b) ? a : b);

    final daysWithoutUpdate = latestDate == null
        ? 999
        : DateTime.now().difference(latestDate).inDays;

    final missedDoses = _medicationReminders
        .map((row) => _asInt(row['dosis_falladas']) ?? 0)
        .fold<int>(0, (a, b) => a + b);

    final criticalGlucose = glucose != null && (glucose < 60 || glucose > 250);
    final reviewGlucose = glucose != null && (glucose < 70 || glucose > 180);

    final criticalPressure = systolic != null &&
        diastolic != null &&
        (systolic >= 180 || diastolic >= 120);
    final reviewPressure = systolic != null &&
        diastolic != null &&
        (systolic >= 140 || diastolic >= 90);

    final urgentAdherence = missedDoses >= 3;
    final reviewAdherence = missedDoses > 0;
    final staleData = daysWithoutUpdate >= 3;
    final moderateStaleData = daysWithoutUpdate >= 1;
    final noClinicalData = glucose == null && (systolic == null || diastolic == null);

    if (criticalGlucose || criticalPressure || urgentAdherence) {
      return const _PatientTrafficState(
        level: _TrafficLevel.critical,
        badge: 'URGENTE',
        title: 'Atencion inmediata recomendada',
        summary: 'Hay valores criticos o alta falta de adherencia.',
        bullet: 'Contacta a tu medico hoy y registra una nueva lectura.',
      );
    }

    if (reviewGlucose ||
        reviewPressure ||
        reviewAdherence ||
        staleData ||
        noClinicalData ||
        moderateStaleData) {
      return const _PatientTrafficState(
        level: _TrafficLevel.warning,
        badge: 'REVISION',
        title: 'Necesitas seguimiento cercano',
        summary: 'Se detectaron datos fuera de meta o faltan registros recientes.',
        bullet: 'Registra tus mediciones y revisa tu plan de tratamiento.',
      );
    }

    return const _PatientTrafficState(
      level: _TrafficLevel.stable,
      badge: 'ESTABLE',
      title: 'Tu seguimiento esta en buen estado',
      summary: 'Tus signos y adherencia se encuentran dentro de control.',
      bullet: 'Continua con tus habitos y mantiene tus controles diarios.',
    );
  }

  DateTime? _parseHomeDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _latestClinicalUpdateLabel() {
    final latestDates = <DateTime?>[
      _parseHomeDate(_ultimaGlucosa?['fecha']),
      _parseHomeDate(_ultimaPresion?['fecha']),
    ].whereType<DateTime>().toList();

    if (latestDates.isEmpty) {
      return 'Sin registros';
    }

    final latest = latestDates.reduce((a, b) => a.isAfter(b) ? a : b);
    final now = DateTime.now();

    if (latest.year == now.year && latest.month == now.month && latest.day == now.day) {
      final hh = latest.hour.toString().padLeft(2, '0');
      final mm = latest.minute.toString().padLeft(2, '0');
      return 'Hoy, $hh:$mm';
    }

    return '${latest.day}/${latest.month}';
  }

  Widget _buildTreatmentNotificationCard(Map<String, dynamic> row) {
    final medication = _asString(row['medicamento']) ?? 'Medicamento';
    final frequency = _asString(row['frecuencia']) ?? 'Frecuencia no definida';
    final status = _reminderStatus(row);
    final missed = _asInt(row['dosis_falladas']) ?? 0;
    final pending = ((_asInt(row['dosis_esperadas']) ?? 0) -
            (_asInt(row['dosis_tomadas']) ?? 0))
        .clamp(0, 999999);

    final statusColor = missed > 0
        ? const Color(0xFFB91C1C)
        : (pending > 0 ? const Color(0xFFB45309) : const Color(0xFF15803D));
    final statusBg = missed > 0
        ? const Color(0xFFFEE2E2)
        : (pending > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFDCFCE7));

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.aliceBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.prussianBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Frecuencia: $frequency',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
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

    final glucosaValue = HomeScreen.formatMetricDisplay(
      type: 'glucosa',
      data: _ultimaGlucosa ?? const <String, dynamic>{},
    );

    final presionValue = HomeScreen.formatMetricDisplay(
      type: 'presion',
      data: _ultimaPresion ?? const <String, dynamic>{},
    );
    final trafficState = _buildPatientTrafficState();
    final stateColors = trafficState.colors;
    final stateIcon = trafficState.icon;
    final latestUpdateLabel = _latestClinicalUpdateLabel();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const MedicalChatFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP APP BAR (Avatar & Saludo)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.aliceBlue,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLINIK',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            'Buenos días, $_patientName 👋',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.prussianBlue,
                            ),
                          ),
                          const Text(
                            '¿Cómo va tu día?',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
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
              const SizedBox(height: 20),

              // 2. HERO CARD DE ESTADO (Tranquilidad)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: stateColors.soft,
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: stateColors.badgeBackground,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 4,
                                      backgroundColor: stateColors.dot,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      trafficState.badge,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: stateColors.badgeText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                trafficState.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.prussianBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Última actualización: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    latestUpdateLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.prussianBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: stateColors.iconBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            stateIcon,
                            color: stateColors.icon,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: stateColors.icon,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  trafficState.bullet,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: stateColors.icon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: stateColors.icon,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trafficState.summary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildAiAnalysisCard(context),
              const SizedBox(height: 24),

              // 3. SECCIÓN: TU RESUMEN DE HOY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Tu resumen de hoy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  Text(
                    '3 de 3 completados',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // GRID DE MÉTRICAS (Glucosa y Presión)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'GLUCOSA',
                      value: glucosaValue,
                      unit: _ultimaGlucosa?['unidad']?.toString() ?? 'mg/dL',
                      time: _formatDateLabel(_ultimaGlucosa?['fecha']),
                      status: _getRangeStatus('glucosa', _ultimaGlucosa),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PRESIÓN',
                      value: presionValue,
                      unit: 'mmHg',
                      time: _formatDateLabel(_ultimaPresion?['fecha']),
                      status: _getRangeStatus('presion', _ultimaPresion),
                      isPressure: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Card 3: Medicamento (Ancho completo)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.aliceBlue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.medication_outlined,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'MEDICAMENTO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Metformina · 850mg',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.prussianBlue,
                              ),
                            ),
                            Text(
                              'Toma de la mañana · 08:00',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.done_all,
                            size: 16,
                            color: Color(0xFF15803D),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tomado',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. SECCIÓN: REGISTRAR AHORA
              const Text(
                'Registrar ahora',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Toca para guardar una nueva lectura',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),

              _buildRegisterMenuButton(context),
              const SizedBox(height: 24),

              // 5. SECCIÓN: RECORDATORIOS DE TRATAMIENTO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recordatorios de tratamiento',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  Text(
                    '${_medicationReminders.length} activos',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_medicationReminders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: const Text(
                    'No hay recordatorios de tratamientos por ahora.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                )
              else
                ..._medicationReminders.map(_buildTreatmentNotificationCard),
              const SizedBox(height: 6),
              const SizedBox(height: 16),

              // 6. CONTACTO DE EMERGENCIA
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.aliceBlue.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFDAD6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.emergency,
                              color: Color(0xFFBA1A1A),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contacto de Emergencia',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.prussianBlue,
                                  ),
                                ),
                                Text(
                                  _emergencyContactLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.call,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () {},
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

  // Widget auxiliar para Tarjetas de Métrica (Glucosa / Presión)
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String time,
    required String status,
    bool isPressure = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF15803D),
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isPressure ? 26 : 38,
                  fontWeight: FontWeight.w800,
                  color: AppColors.prussianBlue,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiAnalysisCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.10),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Asistente IA de salud',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Obtén un análisis general del paciente con explicación de hallazgos y recomendaciones prácticas basadas en la información registrada.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.prussianBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiHealthAnalysisScreen(),
                  ),
                );
              },
              child: const Text(
                'Ver análisis de IA',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para Botones de Acción Gigantes
  Widget _buildActionButton({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.aliceBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: AppColors.primary, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterMenuButton(BuildContext context) {
    return _buildActionButton(
      icon: Icons.add_circle_outline,
      iconBg: AppColors.aliceBlue,
      iconColor: AppColors.primary,
      title: 'Registrar nueva medición o actividad',
      subtitle: 'Selecciona el tipo de registro rápido',
      onTap: () => _showRegisterOptionsSheet(context),
    );
  }

  void _showRegisterOptionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrar nueva medición o\nactividad',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: AppColors.prussianBlue,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Selecciona el tipo de registro rápido',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.aliceBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          splashRadius: 16,
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.close,
                            size: 17,
                            color: Color(0xFF8A93A6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildRegisterOptionTile(
                    icon: Icons.water_drop,
                    iconBg: const Color(0xFFFEF2F2),
                    iconColor: const Color(0xFFDC2626),
                    title: 'Registrar glucosa',
                    subtitle: 'Nivel de azúcar capilar',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterGlucoseScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildRegisterOptionTile(
                    icon: Icons.favorite,
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: AppColors.primary,
                    title: 'Registrar presión',
                    subtitle: 'Tensión sistólica y diastólica',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterPressureScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildRegisterOptionTile(
                    icon: Icons.medication,
                    iconBg: const Color(0xFFF0FDFA),
                    iconColor: AppColors.primary,
                    title: 'Registrar medicamento',
                    subtitle: 'Confirmar dosis tomada o nueva',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Registro de medicamento disponible pronto.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildRegisterOptionTile(
                    icon: Icons.restaurant,
                    iconBg: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFF97316),
                    title: 'Registrar alimentos',
                    subtitle: 'Comidas, snacks y porciones del día',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PatientNutritionScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildRegisterOptionTile(
                    icon: Icons.directions_run,
                    iconBg: const Color(0xFFFEFCE8),
                    iconColor: const Color(0xFFCA8A04),
                    title: 'Registrar actividad',
                    subtitle: 'Caminata, paseo o ejercicio físico',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PatientActivityScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegisterOptionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 21),
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
                      fontWeight: FontWeight.w800,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TrafficLevel { stable, warning, critical }

class _PatientTrafficState {
  const _PatientTrafficState({
    required this.level,
    required this.badge,
    required this.title,
    required this.summary,
    required this.bullet,
  });

  final _TrafficLevel level;
  final String badge;
  final String title;
  final String summary;
  final String bullet;

  IconData get icon {
    switch (level) {
      case _TrafficLevel.stable:
        return Icons.verified_user;
      case _TrafficLevel.warning:
        return Icons.warning_amber_rounded;
      case _TrafficLevel.critical:
        return Icons.emergency;
    }
  }

  _TrafficColors get colors {
    switch (level) {
      case _TrafficLevel.stable:
        return const _TrafficColors(
          badgeBackground: Color(0xFFDCFCE7),
          badgeText: Color(0xFF14532D),
          dot: Color(0xFF16A34A),
          iconBackground: Color(0xFFE6F9EF),
          icon: Color(0xFF15803D),
          soft: Color.fromRGBO(22, 163, 74, 0.14),
        );
      case _TrafficLevel.warning:
        return const _TrafficColors(
          badgeBackground: Color(0xFFFFF7ED),
          badgeText: Color(0xFF9A3412),
          dot: Color(0xFFF59E0B),
          iconBackground: Color(0xFFFFEDD5),
          icon: Color(0xFFB45309),
          soft: Color.fromRGBO(245, 158, 11, 0.14),
        );
      case _TrafficLevel.critical:
        return const _TrafficColors(
          badgeBackground: Color(0xFFFEE2E2),
          badgeText: Color(0xFF991B1B),
          dot: Color(0xFFEF4444),
          iconBackground: Color(0xFFFEE2E2),
          icon: Color(0xFFB91C1C),
          soft: Color.fromRGBO(239, 68, 68, 0.14),
        );
    }
  }
}

class _TrafficColors {
  const _TrafficColors({
    required this.badgeBackground,
    required this.badgeText,
    required this.dot,
    required this.iconBackground,
    required this.icon,
    required this.soft,
  });

  final Color badgeBackground;
  final Color badgeText;
  final Color dot;
  final Color iconBackground;
  final Color icon;
  final Color soft;
}
