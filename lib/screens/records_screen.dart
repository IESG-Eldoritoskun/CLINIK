import 'package:clinik/screens/register_glucose_screen.dart';
import 'package:clinik/screens/register_pressure_screen.dart';
import 'package:clinik/widgets/medical_chat_floating_button.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_colors.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _selectedMetric = 0;
  int _selectedPeriod = 0;
  bool _isLoading = true;
  String? _loadError;

  Map<String, dynamic>? _perfil;
  dynamic _patientId;
  List<Map<String, dynamic>> _glucoseRecords = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _pressureRecords = <Map<String, dynamic>>[];

  late final List<_MockAppointment> _mockAppointments;

  @override
  void initState() {
    super.initState();
    _mockAppointments = _buildMockAppointments();
    _loadRecordsData();
  }

  Future<void> _loadRecordsData() async {
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

      final glucoseFuture = patientId == null
          ? Future.value(<Map<String, dynamic>>[])
          : _loadMetricRows(
              table: 'mediciones',
              patientId: patientId,
              extraFilterColumn: 'tipo',
              extraFilterValue: 'glucosa',
            );

      final pressureFuture = patientId == null
          ? Future.value(<Map<String, dynamic>>[])
          : _loadMetricRows(
              table: 'presiones_arteriales',
              patientId: patientId,
            );

      final results = await Future.wait<dynamic>([
        perfilFuture,
        glucoseFuture,
        pressureFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _perfil = results[0] as Map<String, dynamic>?;
        _patientId = patientId;
        _glucoseRecords = List<Map<String, dynamic>>.from(results[1] as List);
        _pressureRecords = List<Map<String, dynamic>>.from(results[2] as List);
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error al cargar registros: $error');
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudieron cargar tus registros.';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadMetricRows({
    required String table,
    required dynamic patientId,
    String? extraFilterColumn,
    dynamic extraFilterValue,
  }) async {
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
        var query = _supabase.from(table).select().eq('id_paciente', candidate);
        if (extraFilterColumn != null) {
          query = query.eq(extraFilterColumn, extraFilterValue);
        }

        final rows = await query.order('fecha', ascending: false).limit(120);
        if (rows.isNotEmpty) {
          return List<Map<String, dynamic>>.from(rows);
        }
      } catch (_) {
        // Intenta con el siguiente tipo de id.
      }
    }

    return <Map<String, dynamic>>[];
  }

  String get _patientName {
    final parts = <String>[
      _asString(_perfil?['nombre']) ?? '',
      _asString(_perfil?['apellido_paterno']) ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'Paciente';
    }
    return parts.join(' ');
  }

  int get _selectedDays {
    switch (_selectedPeriod) {
      case 1:
        return 30;
      case 2:
        return 90;
      default:
        return 7;
    }
  }

  bool get _isGlucoseSelected => _selectedMetric == 0;

  List<Map<String, dynamic>> get _selectedRecords {
    final source = _isGlucoseSelected ? _glucoseRecords : _pressureRecords;
    final cutoff = DateTime.now().subtract(Duration(days: _selectedDays));
    return source.where((row) {
      final date = _parseDate(row['fecha']);
      return date != null && !date.isBefore(cutoff);
    }).toList();
  }

  List<Map<String, dynamic>> get _secondaryRecords {
    return _isGlucoseSelected ? _pressureRecords : _glucoseRecords;
  }

  Map<String, dynamic>? get _latestSelectedRecord {
    final records = _selectedRecords;
    if (records.isNotEmpty) {
      return records.first;
    }
    final source = _isGlucoseSelected ? _glucoseRecords : _pressureRecords;
    return source.isEmpty ? null : source.first;
  }

  Map<String, dynamic>? get _latestSecondaryRecord {
    return _secondaryRecords.isEmpty ? null : _secondaryRecords.first;
  }

  String get _selectedMetricTitle {
    return _isGlucoseSelected ? 'Glucosa' : 'Presión arterial';
  }

  String get _periodLabel {
    switch (_selectedPeriod) {
      case 1:
        return 'Últimos 30 días';
      case 2:
        return 'Últimos 3 meses';
      default:
        return 'Últimos 7 días';
    }
  }

  String get _summaryValue {
    final records = _selectedRecords;
    if (records.isEmpty) {
      return _isGlucoseSelected ? '--' : '-- / --';
    }

    if (_isGlucoseSelected) {
      final values = records
          .map((row) => _asNum(row['valor']) ?? _asNum(row['value']))
          .whereType<num>()
          .toList();
      if (values.isEmpty) return '--';
      final average = values.reduce((a, b) => a + b) / values.length;
      return average.toStringAsFixed(
        average.truncateToDouble() == average ? 0 : 1,
      );
    }

    final systolicValues = records
        .map((row) => _asNum(row['sistolica']) ?? _asNum(row['systolic']))
        .whereType<num>()
        .toList();
    final diastolicValues = records
        .map((row) => _asNum(row['diastolica']) ?? _asNum(row['diastolic']))
        .whereType<num>()
        .toList();
    if (systolicValues.isEmpty || diastolicValues.isEmpty) {
      return '-- / --';
    }
    final avgSys =
        (systolicValues.reduce((a, b) => a + b) / systolicValues.length)
            .round();
    final avgDia =
        (diastolicValues.reduce((a, b) => a + b) / diastolicValues.length)
            .round();
    return '$avgSys / $avgDia';
  }

  String get _summaryUnit {
    return _isGlucoseSelected ? 'mg/dL prom.' : 'mmHg prom.';
  }

  String get _goalRangeText {
    return _isGlucoseSelected ? '70 – 130 mg/dL' : 'Menor a 120 / 80 mmHg';
  }

  String get _latestReadingLabel {
    final row = _latestSelectedRecord;
    if (row == null) return 'Sin registros recientes';
    return 'Última lectura: ${_formatDateLabel(row['fecha'])}';
  }

  String get _progressLabel {
    final records = _selectedRecords;
    if (records.isEmpty) return 'Sin datos';
    final inRange = records.where(_isRecordInRange).length;
    final percentage = ((inRange / records.length) * 100).round();
    return '$percentage% en meta';
  }

  String get _stabilityLabel {
    final records = _selectedRecords;
    if (records.isEmpty) return 'Sin datos';

    final inRange = records.where(_isRecordInRange).length;
    final ratio = inRange / records.length;
    if (ratio >= 0.8) {
      return _isGlucoseSelected ? 'Estable' : 'Óptima';
    }
    if (ratio >= 0.5) {
      return 'Vigilada';
    }
    return 'Revisar';
  }

  bool get _isUpToDate {
    final row = _latestSelectedRecord;
    final date = row == null ? null : _parseDate(row['fecha']);
    if (date == null) return false;
    return DateTime.now().difference(date).inDays <= 7;
  }

  Future<void> _openAddMeasurement() async {
    final route = MaterialPageRoute<void>(
      builder: (_) => _isGlucoseSelected
          ? const RegisterGlucoseScreen()
          : const RegisterPressureScreen(),
    );

    await Navigator.push(context, route);
    await _loadRecordsData();
  }

  void _openAppointmentsCalendarModal() {
    DateTime monthCursor = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime? selectedDay;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final monthDays = _buildMonthGrid(monthCursor);
            final monthAppointments = _appointmentsForMonth(monthCursor);
            final grouped = _groupAppointmentsByDay(monthAppointments);
            final selectedKey = selectedDay == null ? null : _dateKey(selectedDay!);
            final selectedAppointments = selectedKey == null
                ? const <_MockAppointment>[]
                : (grouped[selectedKey] ?? const <_MockAppointment>[]);

            return DraggableScrollableSheet(
              initialChildSize: 0.86,
              minChildSize: 0.65,
              maxChildSize: 0.94,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF0EA5A4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Calendario de citas (simulado)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                monthCursor = DateTime(monthCursor.year, monthCursor.month - 1, 1);
                                selectedDay = null;
                              });
                            },
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Text(
                            _monthYearLabel(monthCursor),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.prussianBlue,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                monthCursor = DateTime(monthCursor.year, monthCursor.month + 1, 1);
                                selectedDay = null;
                              });
                            },
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List<Widget>.generate(7, (index) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                _weekdayByIndex(index),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: monthDays.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final day = monthDays[index];
                          if (day == null) {
                            return const SizedBox.shrink();
                          }

                          final key = _dateKey(day);
                          final isCurrentMonth = day.month == monthCursor.month;
                          final hasAppointment = grouped.containsKey(key);
                          final isSelected = selectedKey != null && key == selectedKey;
                          final today = _dateKey(DateTime.now());
                          final isToday = key == today;

                          final bgColor = isSelected
                              ? AppColors.primary
                              : (hasAppointment
                                  ? AppColors.aliceBlue.withValues(alpha: 0.8)
                                  : Colors.white);
                          final textColor = isSelected
                              ? Colors.white
                              : (isCurrentMonth ? AppColors.prussianBlue : Colors.grey.shade400);

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: isCurrentMonth
                                ? () {
                                    setModalState(() {
                                      selectedDay = day;
                                    });
                                  }
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isToday
                                      ? AppColors.warning
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (hasAppointment)
                                    Positioned(
                                      bottom: 5,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.white : AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (selectedDay == null)
                        _buildAppointmentsHint(monthAppointments.length)
                      else
                        _buildAppointmentsForSelectedDay(
                          selectedDay: selectedDay!,
                          items: selectedAppointments,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAppointmentsHint(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Text(
        count == 0
            ? 'No hay citas simuladas para este mes.'
            : 'Toca una fecha para ver el detalle de las citas simuladas.',
        style: const TextStyle(fontSize: 13, color: AppColors.prussianBlue),
      ),
    );
  }

  Widget _buildAppointmentsForSelectedDay({
    required DateTime selectedDay,
    required List<_MockAppointment> items,
  }) {
    final dateText = '${selectedDay.day}/${selectedDay.month}/${selectedDay.year}';
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Text(
          'Sin citas programadas para el $dateText.',
          style: const TextStyle(fontSize: 13, color: AppColors.prussianBlue),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Citas para el $dateText',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.prussianBlue,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.aliceBlue.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.prussianBlue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.timeLabel} · ${item.doctorName}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.location,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<_MockAppointment> _buildMockAppointments() {
    final now = DateTime.now();

    DateTime makeDate(int dayOffset, int hour, int minute) {
      final base = now.add(Duration(days: dayOffset));
      return DateTime(base.year, base.month, base.day, hour, minute);
    }

    return <_MockAppointment>[
      _MockAppointment(
        dateTime: makeDate(2, 9, 30),
        title: 'Control de glucosa',
        doctorName: 'Dra. Morales',
        location: 'Consultorio A-12',
      ),
      _MockAppointment(
        dateTime: makeDate(5, 16, 0),
        title: 'Seguimiento de presión',
        doctorName: 'Dr. Paredes',
        location: 'Teleconsulta',
      ),
      _MockAppointment(
        dateTime: makeDate(11, 10, 15),
        title: 'Ajuste de tratamiento',
        doctorName: 'Dra. Cáceres',
        location: 'Consultorio B-04',
      ),
      _MockAppointment(
        dateTime: makeDate(16, 8, 45),
        title: 'Control general',
        doctorName: 'Dr. Rojas',
        location: 'Clínik Centro',
      ),
      _MockAppointment(
        dateTime: makeDate(24, 14, 30),
        title: 'Evaluación nutricional',
        doctorName: 'Lic. Ramírez',
        location: 'Nutrición - Piso 2',
      ),
      _MockAppointment(
        dateTime: makeDate(36, 9, 0),
        title: 'Laboratorio de control',
        doctorName: 'Lab Clínik',
        location: 'Sede Norte',
      ),
      _MockAppointment(
        dateTime: makeDate(42, 17, 20),
        title: 'Revisión de adherencia',
        doctorName: 'Dra. Torres',
        location: 'Teleconsulta',
      ),
    ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  DateTime _dateKey(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Map<DateTime, List<_MockAppointment>> _groupAppointmentsByDay(
    List<_MockAppointment> items,
  ) {
    final grouped = <DateTime, List<_MockAppointment>>{};
    for (final item in items) {
      final key = _dateKey(item.dateTime);
      grouped.putIfAbsent(key, () => <_MockAppointment>[]).add(item);
    }
    return grouped;
  }

  List<_MockAppointment> _appointmentsForMonth(DateTime month) {
    return _mockAppointments
        .where((item) => item.dateTime.year == month.year && item.dateTime.month == month.month)
        .toList();
  }

  List<DateTime?> _buildMonthGrid(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = first.weekday - 1;

    final cells = <DateTime?>[];
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(null);
    }

    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(month.year, month.month, day));
    }

    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  String _monthYearLabel(DateTime date) {
    const months = <String>[
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _weekdayByIndex(int index) {
    const labels = <String>['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return labels[index];
  }

  num? _asNum(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  String? _asString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _formatDateLabel(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return 'Sin registro';

    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Hoy, $hour:$minute';
    }

    final isYesterday =
        now.difference(DateTime(date.year, date.month, date.day)).inDays == 1;
    if (isYesterday) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Ayer, $hour:$minute';
    }

    return '${date.day}/${date.month}';
  }

  bool _isRecordInRange(Map<String, dynamic> row) {
    if (_isGlucoseSelected) {
      final value = _asNum(row['valor']) ?? _asNum(row['value']);
      return value != null && value >= 70 && value <= 130;
    }

    final systolic = _asNum(row['sistolica']) ?? _asNum(row['systolic']);
    final diastolic = _asNum(row['diastolica']) ?? _asNum(row['diastolic']);
    return systolic != null && diastolic != null && systolic < 120 && diastolic < 80;
  }

  String _recordValue(Map<String, dynamic> row, {required bool glucose}) {
    if (glucose) {
      final value = _asNum(row['valor']) ?? _asNum(row['value']);
      if (value == null) return '--';
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} mg/dL';
    }

    final systolic = _asNum(row['sistolica']) ?? _asNum(row['systolic']);
    final diastolic = _asNum(row['diastolica']) ?? _asNum(row['diastolic']);
    if (systolic == null || diastolic == null) return '-- / --';
    return '${systolic.toInt()} / ${diastolic.toInt()}';
  }

  String _recordStatus(Map<String, dynamic> row, {required bool glucose}) {
    if (glucose) {
      final origin = _asString(row['origen']);
      return origin == null ? 'Registro manual' : 'Origen: $origin';
    }

    final pulse = _asNum(row['frecuencia']) ?? _asNum(row['pulso']);
    return pulse == null ? 'Presión registrada' : 'Pulso ${pulse.toInt()} lpm';
  }

  String _recordTag(Map<String, dynamic> row, {required bool glucose}) {
    if (glucose) {
      final value = _asNum(row['valor']) ?? _asNum(row['value']);
      if (value == null) return 'Sin dato';
      if (value < 70) return 'Baja';
      if (value <= 130) return 'En rango';
      return 'Alta';
    }

    final systolic = _asNum(row['sistolica']) ?? _asNum(row['systolic']);
    final diastolic = _asNum(row['diastolica']) ?? _asNum(row['diastolic']);
    if (systolic == null || diastolic == null) return 'Sin dato';
    if (systolic < 120 && diastolic < 80) return 'Óptima';
    if (systolic < 130 && diastolic < 85) return 'Buena';
    return 'Revisar';
  }

  List<Map<String, String>> _chartPoints() {
    final records = _selectedRecords.take(7).toList().reversed.toList();
    return records.map((row) {
      final date = _parseDate(row['fecha']);
      final day = date == null ? '--' : _dayLabel(date);
      final value = _isGlucoseSelected
          ? ((_asNum(row['valor']) ?? _asNum(row['value']))?.round().toString() ?? '--')
          : ((_asNum(row['sistolica']) ?? _asNum(row['systolic']))?.round().toString() ?? '--');
      return {'day': day, 'val': value};
    }).toList();
  }

  String _dayLabel(DateTime date) {
    const weekDays = <int, String>{
      DateTime.monday: 'Lun',
      DateTime.tuesday: 'Mar',
      DateTime.wednesday: 'Mié',
      DateTime.thursday: 'Jue',
      DateTime.friday: 'Vie',
      DateTime.saturday: 'Sáb',
      DateTime.sunday: 'Dom',
    };
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hoy';
    }
    return weekDays[date.weekday] ?? '--';
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

    final selectedRecords = _selectedRecords;
    final secondaryRecord = _latestSecondaryRecord;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const MedicalChatFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecordsData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.aliceBlue,
                          child: Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CLINIK',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Mis registros',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.prussianBlue,
                              ),
                            ),
                            Text(
                              _patientName,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: _isUpToDate ? AppColors.primary : AppColors.critical,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isUpToDate ? 'Al día' : 'Pendiente',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isUpToDate ? AppColors.primary : AppColors.critical,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _openAppointmentsCalendarModal,
                  child: Ink(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF0EA5A4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.event_available_rounded, color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ver calendario de citas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                          Text(
                            '$_selectedMetricTitle · $_periodLabel',
                            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.stable.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 14, color: AppColors.stable),
                                const SizedBox(width: 4),
                                Text(
                                  _stabilityLabel,
                                  style: const TextStyle(fontSize: 12, color: AppColors.stable, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$_summaryValue ',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            TextSpan(
                              text: _summaryUnit,
                              style: const TextStyle(fontSize: 14, color: AppColors.prussianBlue, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.aliceBlue.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_box_outlined, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Rango saludable objetivo', style: TextStyle(fontSize: 12, color: AppColors.prussianBlue)),
                              ],
                            ),
                            Text(
                              _goalRangeText,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildChartVisualization(),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _latestReadingLabel,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Row(
                            children: [
                              Text(
                                '$_progressLabel ',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                        child: Icon(
                          _isGlucoseSelected ? Icons.favorite_border : Icons.water_drop_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _isGlucoseSelected ? 'Presión arterial' : 'Glucosa',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.stable.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    secondaryRecord == null ? 'Sin datos' : _recordTag(secondaryRecord, glucose: !_isGlucoseSelected),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.stable),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              secondaryRecord == null ? 'Sin registros aún' : 'Último control · ${_formatDateLabel(secondaryRecord['fecha'])}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      RichText(
                        textAlign: TextAlign.end,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: secondaryRecord == null ? '--\n' : '${_recordValue(secondaryRecord, glucose: !_isGlucoseSelected)}\n',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                            ),
                            TextSpan(
                              text: _isGlucoseSelected ? 'mmHg' : 'mg/dL',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Registros recientes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.prussianBlue),
                    ),
                    TextButton(
                      onPressed: selectedRecords.isEmpty ? null : () {},
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
                if (selectedRecords.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
                    ),
                    child: const Text(
                      'Todavía no hay registros para el periodo seleccionado.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  )
                else
                  ...selectedRecords.take(6).map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildHistoryTile(
                        _recordValue(row, glucose: _isGlucoseSelected),
                        _formatDateLabel(row['fecha']),
                        _recordStatus(row, glucose: _isGlucoseSelected),
                        _recordTag(row, glucose: _isGlucoseSelected),
                        icon: _isGlucoseSelected ? Icons.water_drop_outlined : Icons.favorite_border,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.aliceBlue.withValues(alpha: 0.5),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _patientId == null ? null : _openAddMeasurement,
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    label: Text(
                      _isGlucoseSelected ? 'Añadir nueva medición de glucosa' : 'Añadir nueva medición de presión',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, int index) {
    final isSelected = _selectedPeriod == index;
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

  Widget _buildChartVisualization() {
    final points = _chartPoints();
    if (points.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.aliceBlue.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No hay datos suficientes para la gráfica.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final numericValues = points
        .map((point) => double.tryParse(point['val'] ?? ''))
        .whereType<double>()
        .toList();
    final maxValue = numericValues.isEmpty ? 1.0 : numericValues.reduce((a, b) => a > b ? a : b);

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
              children: points.map((point) {
                final value = double.tryParse(point['val'] ?? '') ?? 0;
                final barHeight = maxValue == 0 ? 18.0 : (value / maxValue) * 56 + 18;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      point['val'] ?? '--',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 10,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
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
            children: points.map((point) {
              return Text(
                point['day'] ?? '--',
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(
    String value,
    String date,
    String status,
    String tag, {
    required IconData icon,
  }) {
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
                child: Icon(icon, color: AppColors.primary, size: 20),
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
                      Text(
                        status,
                        style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
                      ),
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

class _MockAppointment {
  const _MockAppointment({
    required this.dateTime,
    required this.title,
    required this.doctorName,
    required this.location,
  });

  final DateTime dateTime;
  final String title;
  final String doctorName;
  final String location;

  String get timeLabel {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}