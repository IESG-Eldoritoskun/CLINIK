import 'dart:async';

import 'package:clinik/widgets/medical_chat_floating_button.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_colors.dart';

enum _MessageTone { success, info, warning, error }

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _clockTimer;
  final Set<String> _locallyTakenTreatmentIds = <String>{};
  final bool _simulateDbSave = true;
  bool _canPersistInDb = true;

  bool _isLoading = true;
  String? _loadError;
  Map<String, dynamic>? _perfil;
  List<_MedicationDose> _doses = <_MedicationDose>[];

  @override
  void initState() {
    super.initState();
    _loadMedicationData();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMedicationData() async {
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
      final dosesFuture = patientId == null
          ? Future.value(<_MedicationDose>[])
          : _loadMedicationDoses(patientId);

      final results = await Future.wait<dynamic>([perfilFuture, dosesFuture]);

      if (!mounted) return;
      setState(() {
        _perfil = results[0] as Map<String, dynamic>?;
        _doses = results[1] as List<_MedicationDose>;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error al cargar medicamentos: $error');
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudieron cargar tus medicamentos.';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDose(_MedicationDose dose) async {
    final treatmentId = dose.treatmentId;
    if (treatmentId == null || treatmentId.isEmpty) {
      _showLocalMessage('No se pudo identificar el tratamiento.', tone: _MessageTone.error);
      return;
    }

    if (_simulateDbSave) {
      _markDoseLocally(treatmentId);
      _showLocalMessage('${dose.name} marcada como tomada.', tone: _MessageTone.success);
      return;
    }

    if (!_canPersistInDb) {
      _markDoseLocally(treatmentId);
      _showLocalMessage('Marcada como tomada localmente.', tone: _MessageTone.info);
      return;
    }

    final takenAt = DateTime.now().toIso8601String();
    final updatePayload = <String, dynamic>{
      'estado_toma': 'tomada',
      'fecha_toma': takenAt,
      'hora_toma': takenAt,
      'tomada_en': takenAt,
    };

    try {
      final adherenceUpdated = await _updateAdherenceCounters(dose);
      var treatmentUpdated = false;
      Object? lastTreatmentError;
      for (final keys in [
        ['estado_toma', 'fecha_toma'],
        ['estado_toma', 'hora_toma'],
        ['estado_toma', 'tomada_en'],
        ['estado_toma'],
      ]) {
        try {
          final payload = <String, dynamic>{
            for (final key in keys) key: updatePayload[key],
          };
          await _supabase.from('tratamientos').update(payload).eq('id_tratamiento', treatmentId);
          treatmentUpdated = true;
          break;
        } catch (error) {
          lastTreatmentError = error;
          // Intenta con el siguiente nombre de columna probable.
        }
      }

      if (!adherenceUpdated && !treatmentUpdated) {
        if (lastTreatmentError != null) {
          debugPrint('Detalle de error en tratamientos al confirmar toma: $lastTreatmentError');
        }
        _canPersistInDb = false;
        _markDoseLocally(treatmentId);
        _showLocalMessage(
          'No se pudo guardar en la BD; se marcará localmente mientras se habilita persistencia.',
          tone: _MessageTone.warning,
        );
        return;
      }

      _locallyTakenTreatmentIds.remove(treatmentId);
      if (!mounted) return;
      await _loadMedicationData();
      _showLocalMessage(
        '${dose.name} marcada como tomada a las ${_formatShortTime(takenAt)}.',
        tone: _MessageTone.success,
      );
    } catch (error) {
      debugPrint('Error al confirmar toma: $error');
      _showLocalMessage('No se pudo confirmar la toma.', tone: _MessageTone.error);
    }
  }

  void _markDoseLocally(String treatmentId) {
    if (!mounted) return;
    setState(() {
      _locallyTakenTreatmentIds.add(treatmentId);
      _doses = _doses
          .map((item) => item.treatmentId == treatmentId ? item.markTakenLocally() : item)
          .toList();
    });
  }

  Future<bool> _updateAdherenceCounters(_MedicationDose dose) async {
    final treatmentId = dose.treatmentId;
    if (treatmentId == null || treatmentId.isEmpty) return false;
    final patientId = dose.patientId;

    final currentTaken = dose.takenDoses ?? 0;
    final expected = dose.expectedDoses;
    final nextTaken = expected == null
        ? currentTaken + 1
        : (currentTaken + 1).clamp(0, expected).toInt();

    final payload = <String, dynamic>{
      'dosis_tomadas': nextTaken,
    };

    if (dose.missedDoses != null) {
      final nextMissed = (dose.missedDoses! - 1).clamp(0, 999999).toInt();
      payload['dosis_falladas'] = nextMissed;
    }

    try {
      var query = _supabase
          .from('vista_adherencia_tratamientos')
          .update(payload)
          .eq('id_tratamiento', treatmentId);
      if (patientId != null && patientId.isNotEmpty) {
        query = query.eq('id_paciente', patientId);
      }
      await query;
      return true;
    } catch (error) {
      // Si la vista no es actualizable en el motor de BD, mantenemos la toma confirmada.
      debugPrint('No se pudieron actualizar contadores en vista_adherencia_tratamientos: $error');
      return false;
    }
  }

  Future<List<_MedicationDose>> _loadMedicationDoses(dynamic patientId) async {
    final candidates = <dynamic>{patientId};
    final asText = patientId.toString().trim();
    if (asText.isNotEmpty) {
      candidates.add(asText);
      final asInt = int.tryParse(asText);
      if (asInt != null) {
        candidates.add(asInt);
      }
    }

    List<dynamic> adherenceRows = <dynamic>[];
    for (final candidate in candidates) {
      try {
        final data = await _supabase
            .from('vista_adherencia_tratamientos')
            .select('*')
            .eq('id_paciente', candidate);
        if (data.isNotEmpty) {
          adherenceRows = data;
          break;
        }
      } catch (_) {
        // Intenta con la siguiente variación del id.
      }
    }

    List<dynamic> treatmentRows = <dynamic>[];
    for (final candidate in candidates) {
      try {
        final data = await _supabase
            .from('tratamientos')
            .select('*')
            .eq('id_paciente', candidate)
            .eq('estado', 'activo')
            .order('fecha_inicio', ascending: false);
        if (data.isNotEmpty) {
          treatmentRows = data;
          break;
        }
      } catch (_) {
        // Intenta con la siguiente variación del id.
      }
    }

    final treatmentById = <String, Map<String, dynamic>>{};
    for (final row in treatmentRows.whereType<Map<String, dynamic>>()) {
      final treatmentId = row['id_tratamiento']?.toString().trim();
      if (treatmentId == null || treatmentId.isEmpty) continue;
      treatmentById[treatmentId] = row;
    }

    final doses = <_MedicationDose>[];
    for (final row in adherenceRows.whereType<Map<String, dynamic>>()) {
      final merged = Map<String, dynamic>.from(row);
      final treatmentId = row['id_tratamiento']?.toString().trim();
      if (treatmentId != null && treatmentId.isNotEmpty) {
        final treatmentRow = treatmentById[treatmentId];
        if (treatmentRow != null) {
          merged.addAll(treatmentRow);
        }
      }
      doses.add(_MedicationDose.fromRow(merged));
    }

    if (doses.isEmpty && treatmentRows.isNotEmpty) {
      doses.addAll(
        treatmentRows
            .whereType<Map<String, dynamic>>()
            .map(_MedicationDose.fromRow)
            .where((dose) => dose.name.isNotEmpty),
      );
    }

    if (_locallyTakenTreatmentIds.isNotEmpty) {
      for (var i = 0; i < doses.length; i++) {
        final id = doses[i].treatmentId;
        if (id != null && _locallyTakenTreatmentIds.contains(id)) {
          doses[i] = doses[i].markTakenLocally();
        }
      }
    }

    doses.sort((left, right) {
      final leftPendingRank = left.isPendingNow
          ? 0
          : (left.isMissed ? 2 : (left.isTaken ? 3 : 1));
      final rightPendingRank = right.isPendingNow
          ? 0
          : (right.isMissed ? 2 : (right.isTaken ? 3 : 1));
      if (leftPendingRank != rightPendingRank) {
        return leftPendingRank.compareTo(rightPendingRank);
      }
      return left.sortMinutes.compareTo(right.sortMinutes);
    });

    return doses;
  }

  String get _patientName {
    final parts = <String>[
      _asString(_perfil?['nombre']) ?? '',
      _asString(_perfil?['apellido_paterno']) ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Paciente' : parts.join(' ');
  }

  int get _scheduledCount => _doses.length;

  int get _completedCount => _doses.where((dose) => dose.isTaken).length;

  double get _adherenceRatio {
    if (_scheduledCount == 0) return 0;
    return _completedCount / _scheduledCount;
  }

  int get _adherencePercent => (_adherenceRatio * 100).round();

  int get _streakDays {
    final best = _doses
        .map((dose) => dose.streakDays)
        .whereType<int>()
        .fold<int>(0, (current, value) => value > current ? value : current);
    return best;
  }

  List<_MedicationDose> get _todaySchedule => _doses;

  String get _friendlyReminder {
    final pending = _todaySchedule.where((dose) => !dose.isTaken).toList();
    if (pending.isEmpty) {
      return 'Hoy llevas todas tus tomas registradas. Mantén el mismo horario para sostener la adherencia.';
    }

    final nextDose = pending.first;
    return 'Recuerda ${nextDose.name} ${nextDose.doseLabel}. Un horario constante ayuda a mantener tu tratamiento en control.';
  }

  String? _asString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  void _showLocalMessage(
    String message, {
    _MessageTone tone = _MessageTone.info,
  }) {
    if (!mounted) return;
    final theme = _snackTheme(tone);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.$1,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(theme.$2, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, IconData) _snackTheme(_MessageTone tone) {
    switch (tone) {
      case _MessageTone.success:
        return (const Color(0xFF0E9F6E), Icons.check_circle_outline);
      case _MessageTone.warning:
        return (const Color(0xFFB45309), Icons.warning_amber_rounded);
      case _MessageTone.error:
        return (const Color(0xFFB91C1C), Icons.error_outline_rounded);
      case _MessageTone.info:
        return (AppColors.primary, Icons.info_outline_rounded);
    }
  }

  String _formatShortTime(String isoDate) {
    final date = DateTime.tryParse(isoDate)?.toLocal();
    if (date == null) return '--:--';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final todayLabel = _buildTodayLabel();

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
      floatingActionButton: const MedicalChatFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMedicationData,
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
                              'Mis medicamentos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.prussianBlue,
                              ),
                            ),
                            Text(
                              _patientName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
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
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppColors.prussianBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          todayLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                        '$_scheduledCount programados',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildAdherenceCard(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Horario del día',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    Text(
                      'Vista sincronizada',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_todaySchedule.isEmpty)
                  _buildEmptyState()
                else
                  ..._todaySchedule.map(
                    (dose) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildMedicationCard(dose),
                    ),
                  ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.aliceBlue.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recordatorio amistoso',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.prussianBlue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _friendlyReminder,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildAdherenceCard() {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_outlined, size: 18, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Adherencia esta semana',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.prussianBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scheduledCount == 0
                          ? 'Aún no hay tomas programadas para mostrar.'
                          : 'Seguimiento actualizado con tus tomas registradas.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '$_adherencePercent%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _adherenceRatio.clamp(0, 1),
              minHeight: 8,
              backgroundColor: AppColors.aliceBlue,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 3,
                    backgroundColor: AppColors.prussianBlue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_completedCount de $_scheduledCount tomas completadas',
                    style: const TextStyle(fontSize: 12, color: AppColors.prussianBlue),
                  ),
                ],
              ),
              Text(
                'Racha: $_streakDays días',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(_MedicationDose dose) {
    final badgeColor = dose.isTaken
      ? AppColors.stable
      : (dose.isPendingNow
        ? AppColors.warning
        : (dose.isMissed ? AppColors.critical : AppColors.primary));
    final badgeBackground = dose.isTaken
      ? AppColors.stable.withValues(alpha: 0.12)
      : (dose.isPendingNow
        ? AppColors.warning.withValues(alpha: 0.15)
        : (dose.isMissed
          ? AppColors.critical.withValues(alpha: 0.12)
          : AppColors.aliceBlue));
    final iconBackground = dose.isTaken
        ? AppColors.aliceBlue
      : (dose.isPendingNow
        ? const Color(0xFFFEF3C7)
        : (dose.isMissed ? const Color(0xFFFFE4E6) : Colors.white));
    final canConfirmNow = !dose.isTaken && dose.isPendingNow;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dose.isPendingNow
              ? AppColors.warning
              : (dose.isMissed
                  ? AppColors.critical
                  : Colors.black.withValues(alpha: 0.04)),
          width: (dose.isPendingNow || dose.isMissed) ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: AppColors.prussianBlue),
                  const SizedBox(width: 6),
                  Text(
                    dose.timeLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${dose.periodLabel})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      dose.isTaken
                          ? Icons.check_circle_outline
                          : (dose.isMissed
                              ? Icons.cancel_outlined
                              : Icons.error_outline),
                      size: 14,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dose.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  dose.isTaken
                      ? Icons.medication_outlined
                      : (dose.isMissed
                          ? Icons.report_problem_outlined
                          : Icons.medical_services_outlined),
                  color: dose.isTaken ? AppColors.primary : badgeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dose.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.prussianBlue,
                            ),
                          ),
                        ),
                        if (dose.isPendingNow) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '¡Toca ahora!',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dose.doseLabel,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    if (dose.instructions != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        dose.instructions!,
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (dose.nextDoseLabel != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Próxima toma: ${dose.nextDoseLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.prussianBlue,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    dose.nextPeriodLabel ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
          if (canConfirmNow) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _confirmDose(dose),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Confirmar como tomada'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ] else if (dose.isTaken) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.stable.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined, size: 18, color: AppColors.stable),
                  SizedBox(width: 8),
                  Text(
                    'Toma confirmada',
                    style: TextStyle(
                      color: AppColors.stable,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: const Text(
        'No hay tratamientos sincronizados para este paciente.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
    );
  }

  String _buildTodayLabel() {
    final now = DateTime.now();
    return 'Hoy, ${now.day} de ${_monthNameEs(now.month)}';
  }

  String _monthNameEs(int month) {
    const monthNames = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    if (month < 1 || month > 12) {
      return 'mes';
    }

    return monthNames[month - 1];
  }
}

class _MedicationDose {
  _MedicationDose({
    required this.name,
    required this.timeLabel,
    required this.periodLabel,
    required this.statusLabel,
    required this.isTaken,
    required this.isPendingNow,
    required this.isMissed,
    required this.doseLabel,
    required this.sortMinutes,
    required this.treatmentId,
    this.patientId,
    this.expectedDoses,
    this.takenDoses,
    this.missedDoses,
    this.instructions,
    this.nextDoseLabel,
    this.nextPeriodLabel,
    this.streakDays,
  });

  final String name;
  final String timeLabel;
  final String periodLabel;
  final String statusLabel;
  final bool isTaken;
  final bool isPendingNow;
  final bool isMissed;
  final String doseLabel;
  final int sortMinutes;
  final String? treatmentId;
  final String? patientId;
  final int? expectedDoses;
  final int? takenDoses;
  final int? missedDoses;
  final String? instructions;
  final String? nextDoseLabel;
  final String? nextPeriodLabel;
  final int? streakDays;

  _MedicationDose markTakenLocally() {
    final nextTaken = (takenDoses ?? 0) + 1;
    final nextMissed = missedDoses == null
        ? null
        : (missedDoses! - 1).clamp(0, 999999).toInt();

    return _MedicationDose(
      name: name,
      timeLabel: timeLabel,
      periodLabel: periodLabel,
      statusLabel: 'Tomada',
      isTaken: true,
      isPendingNow: false,
      isMissed: false,
      doseLabel: doseLabel,
      sortMinutes: sortMinutes,
      treatmentId: treatmentId,
      patientId: patientId,
      expectedDoses: expectedDoses,
      takenDoses: nextTaken,
      missedDoses: nextMissed,
      instructions: instructions,
      nextDoseLabel: nextDoseLabel,
      nextPeriodLabel: nextPeriodLabel,
      streakDays: streakDays,
    );
  }

  factory _MedicationDose.fromRow(Map<String, dynamic> row) {
    final treatmentId = row['id_tratamiento']?.toString().trim();
    final patientId = row['id_paciente']?.toString().trim();
    final frequency = _pickString(row, <String>['frecuencia']) ?? 'Sin frecuencia';
    final via = _pickString(row, <String>['via_administracion', 'via']) ?? 'Oral';
    final startDateRaw = _pickString(row, <String>['fecha_inicio']);
    final startDate = _parseAnchorDate(startDateRaw);
    final rawTime = _pickScheduledTime(row);
    final timeLabel = rawTime == null
      ? _frequencyToDisplayLabel(frequency)
      : _formatTimeLabel(rawTime);
    final hasExplicitSchedule = rawTime != null;
    final intervalMinutes = _frequencyToMinutes(frequency);
    final sortMinutes = rawTime == null
      ? intervalMinutes
      : _timeToMinutes(rawTime);
    final rawStatus = (_pickString(row, <String>[
          'estado_toma',
          'estado',
          'estatus',
          'adherencia_estado',
        ]) ??
        '')
        .toLowerCase();
    final takenDoses = _pickInt(row, <String>['dosis_tomadas']) ?? 0;

    final isTaken = rawStatus.contains('tomad') ||
        rawStatus.contains('complet') ||
        rawStatus.contains('realiz') ||
      rawStatus.contains('cumpl') ||
      takenDoses > 0;
    final isPendingNow =
        !isTaken &&
        _looksCurrent(
          sortMinutes,
          rawStatus,
          hasExplicitSchedule,
          intervalMinutes: intervalMinutes,
          anchorDate: startDate,
        );
    final isMissed = !isTaken &&
      !isPendingNow &&
        _looksMissed(
          sortMinutes,
          rawStatus,
          hasExplicitSchedule,
          intervalMinutes: intervalMinutes,
          anchorDate: startDate,
        );

    final doseQuantity = _pickString(row, <String>['dosis', 'dosis_indicada']);
    final doseUnit = _pickString(row, <String>['unidad', 'unidad_dosis']);
    final amount = _pickString(row, <String>['cantidad', 'cantidad_dosis', 'tabletas']);
    final dosageParts = <String>[];
    if (doseQuantity != null) {
      dosageParts.add(doseUnit != null ? '$doseQuantity $doseUnit' : doseQuantity);
    }
    if (amount != null) {
      dosageParts.add(amount);
    }

    return _MedicationDose(
      name: _pickString(row, <String>['nombre_medicamento', 'medicamento', 'nombre']) ?? '',
      timeLabel: timeLabel,
      periodLabel: rawTime == null ? _frequencyShortLabel(frequency) : _periodLabelForMinutes(sortMinutes),
        statusLabel: isTaken
          ? 'Tomada'
          : (isPendingNow ? 'Pendiente' : (isMissed ? 'No tomada' : 'Programada')),
      isTaken: isTaken,
      isPendingNow: isPendingNow,
        isMissed: isMissed,
      doseLabel: dosageParts.isEmpty
          ? '$frequency · $via'
          : '${dosageParts.join(' · ')} · $frequency · $via',
      sortMinutes: sortMinutes,
      treatmentId: treatmentId,
        patientId: patientId,
      expectedDoses: _pickInt(row, <String>['dosis_esperadas', 'dosis_programadas']),
        takenDoses: takenDoses,
      missedDoses: _pickInt(row, <String>['dosis_falladas', 'dosis_faltantes']),
      instructions: _pickString(row, <String>[
        'indicaciones',
        'instrucciones',
        'descripcion_indicacion',
        'recomendacion',
      ]),
      nextDoseLabel: _pickString(row, <String>[
        'proxima_toma',
        'hora_siguiente',
        'siguiente_toma',
      ]),
      nextPeriodLabel: _pickString(row, <String>[
        'periodo_siguiente',
        'momento_siguiente',
      ]),
      streakDays: _pickInt(row, <String>['racha_dias', 'streak_days']),
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

  static int? _pickInt(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static String? _pickScheduledTime(Map<String, dynamic> row) {
    final candidates = <String?>[
      _pickString(row, <String>[
        'hora_programada',
        'hora_toma',
        'hora_sugerida',
        'hora',
        'horario',
        'hora_programada_texto',
        'hora_inicio',
        'hora_fin',
        'hora_dosis',
        'horario_dosis',
        'hora_pauta',
        'hora_recomendada',
        'proxima_toma',
        'siguiente_toma',
      ]),
      row['hora_programada']?.toString(),
      row['hora_toma']?.toString(),
      row['hora_sugerida']?.toString(),
      row['hora']?.toString(),
      row['horario']?.toString(),
      row['hora_programada_texto']?.toString(),
      row['hora_inicio']?.toString(),
      row['hora_dosis']?.toString(),
      row['horario_dosis']?.toString(),
      row['hora_pauta']?.toString(),
      row['hora_recomendada']?.toString(),
    ];

    for (final candidate in candidates) {
      final normalized = _normalizeTimeString(candidate);
      if (normalized != null) {
        return normalized;
      }
    }

    return null;
  }

  static String? _normalizeTimeString(String? value) {
    if (value == null) return null;
    final text = value.trim();
    if (text.isEmpty) return null;

    final timeMatch = RegExp(r'^(\d{1,2})(?::(\d{2}))?(?::\d{2})?$').firstMatch(text);
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(1) ?? '') ?? 0;
      final minute = int.tryParse(timeMatch.group(2) ?? '00') ?? 0;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }

    final parsed = DateTime.tryParse(text)?.toLocal();
    if (parsed != null) {
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return text;
  }

  static DateTime? _parseAnchorDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute);
  }

  static int _frequencyToMinutes(String frequency) {
    final normalized = frequency.toLowerCase();
    final everyMatch = RegExp(r'(?:cada\s*)?(\d+)\s*hora').firstMatch(normalized);
    if (everyMatch != null) {
      final hours = int.tryParse(everyMatch.group(1) ?? '') ?? 24;
      return hours * 60;
    }

    if (normalized.contains('1 hora')) return 60;
    if (normalized.contains('2 horas')) return 2 * 60;
    if (normalized.contains('3 horas')) return 3 * 60;
    if (normalized.contains('4 horas')) return 4 * 60;
    if (normalized.contains('5 horas')) return 5 * 60;
    if (normalized.contains('12 horas')) return 12 * 60;
    if (normalized.contains('8 horas')) return 8 * 60;
    if (normalized.contains('6 horas')) return 6 * 60;
    if (normalized.contains('24 horas')) return 24 * 60;
    if (normalized.contains('una vez')) return 24 * 60;
    return 24 * 60;
  }

  static String _frequencyToDisplayLabel(String frequency) {
    final normalized = frequency.toLowerCase();
    final directMatch = RegExp(r'(?:cada\s*)?(\d+)\s*hora').firstMatch(normalized);
    if (directMatch != null) {
      final hours = directMatch.group(1) ?? '';
      return hours == '1' ? 'Cada 1 hora' : 'Cada $hours horas';
    }

    if (normalized.contains('cada 12')) return 'Cada 12 horas';
    if (normalized.contains('cada 8')) return 'Cada 8 horas';
    if (normalized.contains('cada 6')) return 'Cada 6 horas';
    if (normalized.contains('cada 24')) return 'Cada 24 horas';
    return frequency;
  }

  static String _frequencyShortLabel(String frequency) {
    final normalized = frequency.toLowerCase();
    if (normalized.contains('1 hora')) return '1 h';
    if (normalized.contains('2 horas')) return '2 h';
    if (normalized.contains('3 horas')) return '3 h';
    if (normalized.contains('4 horas')) return '4 h';
    if (normalized.contains('5 horas')) return '5 h';
    if (normalized.contains('6 horas')) return '6 h';
    if (normalized.contains('8 horas')) return '8 h';
    if (normalized.contains('12 horas')) return '12 h';
    if (normalized.contains('24 horas')) return '24 h';
    if (normalized.contains('cada 1')) return '1 h';
    if (normalized.contains('cada 6')) return '6 h';
    if (normalized.contains('cada 8')) return '8 h';
    if (normalized.contains('cada 12')) return '12 h';
    if (normalized.contains('cada 24')) return '24 h';
    return frequency;
  }

  static int _timeToMinutes(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) return 24 * 60;
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(rawTime);
    if (match == null) return 24 * 60;
    final hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    return (hour * 60) + minute;
  }

  static String _formatTimeLabel(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) {
      return 'Sin horario';
    }
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(rawTime);
    if (match == null) {
      return rawTime;
    }
    final hour = (int.tryParse(match.group(1) ?? '') ?? 0)
        .toString()
        .padLeft(2, '0');
    final minute = (int.tryParse(match.group(2) ?? '') ?? 0)
        .toString()
        .padLeft(2, '0');
    return '$hour:$minute hrs';
  }

  static String _periodLabelForMinutes(int minutes) {
    if (minutes < 0 || minutes >= 24 * 60) return '24 h';
    if (minutes < 12 * 60) return 'Mañana';
    if (minutes < 18 * 60) return 'Tarde';
    return 'Noche';
  }

  static bool _looksCurrent(
    int sortMinutes,
    String rawStatus,
    bool hasExplicitSchedule,
    {
    required int intervalMinutes,
    required DateTime? anchorDate,
  }
  ) {
    if (rawStatus.contains('pendient')) return true;

    if (!hasExplicitSchedule) {
      if (intervalMinutes <= 0) return false;
      final now = DateTime.now();
      final anchor = anchorDate ?? DateTime(now.year, now.month, now.day);
      if (now.isBefore(anchor)) return false;

      final elapsedMinutes = now.difference(anchor).inMinutes;
      final offset = elapsedMinutes % intervalMinutes;
      return offset <= 90;
    }

    if (sortMinutes >= 24 * 60) return false;

    final now = TimeOfDay.now();
    final currentMinutes = (now.hour * 60) + now.minute;
    final difference = (currentMinutes - sortMinutes).abs();
    return difference <= 90;
  }

  static bool _looksMissed(
    int sortMinutes,
    String rawStatus,
    bool hasExplicitSchedule,
    {
    required int intervalMinutes,
    required DateTime? anchorDate,
  }
  ) {
    if (rawStatus.contains('tomad') || rawStatus.contains('complet')) return false;
    if (rawStatus.contains('no tom') ||
        rawStatus.contains('fallad') ||
        rawStatus.contains('omit') ||
        rawStatus.contains('vencid')) {
      return true;
    }
    if (rawStatus.contains('programad')) return false;

    if (!hasExplicitSchedule) {
      if (intervalMinutes <= 0) return false;
      final now = DateTime.now();
      final anchor = anchorDate ?? DateTime(now.year, now.month, now.day);
      if (now.isBefore(anchor)) return false;

      final elapsedMinutes = now.difference(anchor).inMinutes;
      final offset = elapsedMinutes % intervalMinutes;
      if (offset <= 90) return false;

      final minutesToNextDose = intervalMinutes - offset;
      return minutesToNextDose > 90;
    }

    if (sortMinutes >= 24 * 60) return false;

    final now = TimeOfDay.now();
    final currentMinutes = (now.hour * 60) + now.minute;
    return (currentMinutes - sortMinutes) > 90;
  }
}
