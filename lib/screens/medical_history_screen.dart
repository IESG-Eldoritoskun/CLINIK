import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_colors.dart';

class MedicalHistoryScreen extends StatefulWidget {
  final String curp;
  final String nss;

  const MedicalHistoryScreen({
    super.key,
    required this.curp,
    required this.nss,
  });

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _loadError;
  bool _isExporting = false;

  String _patientName = 'Paciente';
  String _ageText = '-- años';
  String _curpText = 'No registrado';
  String _nssText = 'No registrado';
  String _diagnosesText = 'Sin diagnósticos registrados';
  String _doctorName = 'Sin médico asignado';
  String _centerName = 'Sin centro de salud';
  String _currentMedication = 'Sin tratamiento activo';
  String _latestGlucose = 'Sin registro';
  String _latestPressure = 'Sin registro';
  String _latestUpdate = 'Sin fecha';

  List<List<String>> _pdfIdentificationRows = const <List<String>>[];
  List<List<String>> _pdfMedicalRows = const <List<String>>[];
  List<List<String>> _pdfFollowupRows = const <List<String>>[];
  List<List<String>> _pdfGlucoseHistoryRows = const <List<String>>[];
  List<List<String>> _pdfPressureHistoryRows = const <List<String>>[];
  List<List<String>> _pdfAdherenceRows = const <List<String>>[];

  @override
  void initState() {
    super.initState();
    _loadMedicalHistory();
  }

  Future<void> _loadMedicalHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'No hay una sesión activa.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final perfilFuture = _supabase
          .from('perfiles')
          .select()
          .eq('id_usuario', userId)
          .maybeSingle();
      final pacienteFuture = _supabase
          .from('pacientes')
          .select()
          .eq('id_usuario', userId)
          .maybeSingle();

      final base = await Future.wait<dynamic>([perfilFuture, pacienteFuture]);
      final perfil = base[0] as Map<String, dynamic>?;
      final paciente = base[1] as Map<String, dynamic>?;
      final patientId = paciente?['id_paciente'];

      final diagnosesFuture = patientId == null
          ? Future.value(<String>[])
          : _loadPatientDiseases(patientId);
      final treatmentsFuture = patientId == null
          ? Future.value(<Map<String, dynamic>>[])
          : _loadTreatments(patientId);
      final glucoseFuture = patientId == null
          ? Future.value(null)
          : _loadLatestByTable(
              table: 'mediciones',
              patientId: patientId,
              extraFilterColumn: 'tipo',
              extraFilterValue: 'glucosa',
            );
      final pressureFuture = patientId == null
          ? Future.value(null)
          : _loadLatestByTable(
              table: 'presiones_arteriales',
              patientId: patientId,
            );
      final doctorContextFuture = patientId == null
          ? Future.value(null)
          : _loadDoctorContext(patientId: patientId, patientUserId: userId);
      final glucoseHistoryFuture = patientId == null
          ? Future.value(<Map<String, dynamic>>[])
          : _loadByPatientCandidates(
              table: 'mediciones',
              patientId: patientId,
              orderColumn: 'fecha',
              limit: 10,
              extraFilterColumn: 'tipo',
              extraFilterValue: 'glucosa',
            );
      final pressureHistoryFuture = patientId == null
          ? Future.value(<Map<String, dynamic>>[])
          : _loadByPatientCandidates(
              table: 'presiones_arteriales',
              patientId: patientId,
              orderColumn: 'fecha',
              limit: 10,
            );
      final adherenceFuture = patientId == null
          ? Future.value(<Map<String, dynamic>>[])
          : _loadAdherenceRows(patientId);

      final extra = await Future.wait<dynamic>([
        diagnosesFuture,
        treatmentsFuture,
        glucoseFuture,
        pressureFuture,
        doctorContextFuture,
        glucoseHistoryFuture,
        pressureHistoryFuture,
        adherenceFuture,
      ]);

      final diagnoses = extra[0] as List<String>;
      final treatments = extra[1] as List<Map<String, dynamic>>;
      final latestGlucoseRow = extra[2] as Map<String, dynamic>?;
      final latestPressureRow = extra[3] as Map<String, dynamic>?;
      final doctorContext = extra[4] as Map<String, dynamic>?;
      final glucoseHistoryRows = extra[5] as List<Map<String, dynamic>>;
      final pressureHistoryRows = extra[6] as List<Map<String, dynamic>>;
      final adherenceRows = extra[7] as List<Map<String, dynamic>>;

      final doctorData = doctorContext?['doctorData'] as Map<String, dynamic>?;
      final doctorProfile = doctorContext?['doctorProfile'] as Map<String, dynamic>?;
      final centerName = _asString(doctorContext?['centerName']);

      final birthDate = DateTime.tryParse(_asString(paciente?['nacimiento']) ?? '');
      final fullName = _buildFullName(perfil);
      final curpFromDb = _asString(paciente?['CURP']);
      final nssFromDb = _asString(paciente?['Numero_Seguro_Social']);
      final curpResolved = widget.curp.trim().isNotEmpty ? widget.curp.trim() : (curpFromDb ?? 'No registrado');
      final nssResolved = widget.nss.trim().isNotEmpty ? widget.nss.trim() : (nssFromDb ?? 'No registrado');

      final latestGlucoseLabel = _formatGlucoseRow(latestGlucoseRow);
      final latestPressureLabel = _formatPressureRow(latestPressureRow);
      final latestDate = _latestDate([latestGlucoseRow, latestPressureRow]);

      final diagnosisText = diagnoses.isEmpty ? 'Sin diagnósticos registrados' : diagnoses.join(', ');
      final medicationText = treatments.isEmpty
          ? 'Sin tratamiento activo'
          : _summarizeTreatment(treatments.first);

      final doctorName = _buildDoctorName(doctorProfile, doctorData);
      final centerText = centerName ??
          _asString(doctorData?['institucion']) ??
          _asString(doctorData?['centro_medico']) ??
          _asString(doctorData?['centro_salud']) ??
          'Sin centro de salud';

      if (!mounted) return;
      setState(() {
        _patientName = fullName;
        _ageText = birthDate == null ? '-- años' : '${_calculateAge(birthDate)} años';
        _curpText = curpResolved;
        _nssText = nssResolved;
        _diagnosesText = diagnosisText;
        _doctorName = doctorName;
        _centerName = centerText;
        _currentMedication = medicationText;
        _latestGlucose = latestGlucoseLabel;
        _latestPressure = latestPressureLabel;
        _latestUpdate = latestDate;
        _pdfIdentificationRows = <List<String>>[
          <String>['Nombre', fullName],
          <String>['Edad', birthDate == null ? '-- años' : '${_calculateAge(birthDate)} años'],
          <String>['CURP', curpResolved],
          <String>['NSS', nssResolved],
        ];
        _pdfMedicalRows = <List<String>>[
          <String>['Diagnósticos', diagnosisText],
          <String>['Médico tratante', doctorName],
          <String>['Centro de salud', centerText],
          <String>['Medicamento actual', medicationText],
        ];
        _pdfFollowupRows = <List<String>>[
          <String>['Glucosa reciente', latestGlucoseLabel],
          <String>['Presión reciente', latestPressureLabel],
          <String>['Última actualización', latestDate],
        ];
        _pdfGlucoseHistoryRows = _buildGlucoseHistoryRows(glucoseHistoryRows);
        _pdfPressureHistoryRows = _buildPressureHistoryRows(pressureHistoryRows);
        _pdfAdherenceRows = _buildAdherenceRows(adherenceRows);
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error al cargar historial médico: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'No se pudo cargar el historial médico desde la base de datos.';
      });
    }
  }

  Future<List<String>> _loadPatientDiseases(dynamic patientId) async {
    final links = await _loadByPatientCandidates(
      table: 'paciente_enfermedades',
      patientId: patientId,
      orderColumn: 'fecha_diagnostico',
    );

    final diseaseIds = links
        .map((row) => row['id_enfermedad'])
        .where((id) => id != null)
        .toList();

    if (diseaseIds.isEmpty) return <String>[];

    try {
      final diseases = await _supabase
          .from('enfermedades')
          .select()
          .inFilter('id_enfermedad', diseaseIds);

      return List<Map<String, dynamic>>.from(diseases)
          .map((row) => _asString(row['nombre_enfermedad']) ?? _asString(row['nombre']) ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTreatments(dynamic patientId) async {
    final rows = await _loadByPatientCandidates(
      table: 'tratamientos',
      patientId: patientId,
      stateFilter: const {'estado': 'activo'},
      orderColumn: 'fecha_inicio',
    );

    if (rows.isNotEmpty) return rows;

    return _loadByPatientCandidates(
      table: 'tratamientos',
      patientId: patientId,
      orderColumn: 'fecha_inicio',
    );
  }

  Future<Map<String, dynamic>?> _loadLatestByTable({
    required String table,
    required dynamic patientId,
    String? extraFilterColumn,
    dynamic extraFilterValue,
  }) async {
    final rows = await _loadByPatientCandidates(
      table: table,
      patientId: patientId,
      orderColumn: 'fecha',
      limit: 1,
      extraFilterColumn: extraFilterColumn,
      extraFilterValue: extraFilterValue,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> _loadAdherenceRows(dynamic patientId) async {
    final rows = await _loadByPatientCandidates(
      table: 'vista_adherencia_tratamientos',
      patientId: patientId,
      limit: 20,
    );

    if (rows.isNotEmpty) {
      return rows;
    }

    return _loadByPatientCandidates(
      table: 'tratamientos',
      patientId: patientId,
      orderColumn: 'fecha_inicio',
      limit: 20,
    );
  }

  Future<List<Map<String, dynamic>>> _loadByPatientCandidates({
    required String table,
    required dynamic patientId,
    Map<String, dynamic>? stateFilter,
    String? orderColumn,
    int limit = 120,
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
        dynamic query = _supabase.from(table).select().eq('id_paciente', candidate);

        if (stateFilter != null) {
          for (final entry in stateFilter.entries) {
            query = query.eq(entry.key, entry.value);
          }
        }

        if (extraFilterColumn != null) {
          query = query.eq(extraFilterColumn, extraFilterValue);
        }

        if (orderColumn != null) {
          query = query.order(orderColumn, ascending: false);
        }

        final rows = await query.limit(limit);
        if (rows.isNotEmpty) {
          return List<Map<String, dynamic>>.from(rows);
        }
      } catch (_) {
        // Intenta con la siguiente variante de id.
      }
    }

    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> _loadDoctorContext({
    required dynamic patientId,
    required String patientUserId,
  }) async {
    Map<String, dynamic>? assignment = await _loadLatestAssignmentByPatient(
      patientId: patientId,
      activeOnly: true,
    );
    assignment ??= await _loadLatestAssignmentByUser(
      userId: patientUserId,
      activeOnly: true,
    );
    assignment ??= await _loadLatestAssignmentByPatient(
      patientId: patientId,
      activeOnly: false,
    );
    assignment ??= await _loadLatestAssignmentByUser(
      userId: patientUserId,
      activeOnly: false,
    );

    final doctorId = assignment?['id_medico'];

    Map<String, dynamic>? doctorData;
    if (doctorId != null) {
      try {
        doctorData = await _supabase
            .from('medicos')
            .select()
            .eq('id_medico', doctorId)
            .maybeSingle();
      } catch (_) {
        doctorData = null;
      }

      if (doctorData == null) {
        try {
          doctorData = await _supabase
              .from('medicos')
              .select()
              .eq('id_usuario', doctorId)
              .maybeSingle();
        } catch (_) {
          doctorData = null;
        }
      }
    }

    Map<String, dynamic>? doctorProfile;
    final doctorUserId = _asString(doctorData?['id_usuario']);
    if (doctorUserId != null) {
      try {
        doctorProfile = await _supabase
            .from('perfiles')
            .select()
            .eq('id_usuario', doctorUserId)
            .maybeSingle();
      } catch (_) {
        doctorProfile = null;
      }
    }

    var centerName =
        _asString(doctorData?['institucion']) ??
        _asString(doctorData?['centro_medico']) ??
        _asString(doctorData?['centro_salud']) ??
        _asString(assignment?['centro_medico']) ??
        _asString(assignment?['centro_salud']) ??
        _asString(assignment?['institucion']);

    final centerId =
        assignment?['id_centro_medico'] ??
        assignment?['id_centro_salud'] ??
        assignment?['id_centro'] ??
        doctorData?['id_centro_medico'] ??
        doctorData?['id_centro_salud'] ??
        doctorData?['id_centro'];

    if (centerName == null && centerId != null) {
      try {
        final centerData = await _supabase
            .from('centros_medicos')
            .select()
            .eq('id_centro_medico', centerId)
            .maybeSingle();
        centerName =
            _asString(centerData?['nombre']) ??
            _asString(centerData?['centro_medico']) ??
            _asString(centerData?['nombre_centro']);
      } catch (_) {
        centerName = null;
      }
    }

    return <String, dynamic>{
      'doctorData': doctorData,
      'doctorProfile': doctorProfile,
      'centerName': centerName,
    };
  }

  Future<Map<String, dynamic>?> _loadLatestAssignmentByPatient({
    required dynamic patientId,
    required bool activeOnly,
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
        var query = _supabase.from('paciente_medico').select().eq('id_paciente', candidate);
        if (activeOnly) {
          query = query.eq('estado', 'activo');
        }

        final assignment = await query
            .order('fecha_asignacion', ascending: false)
            .limit(1)
            .maybeSingle();

        if (assignment != null) {
          return assignment;
        }
      } catch (_) {
        // Sigue intentando con otra variante del id.
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _loadLatestAssignmentByUser({
    required String userId,
    required bool activeOnly,
  }) async {
    try {
      var query = _supabase.from('paciente_medico').select().eq('id_usuario', userId);
      if (activeOnly) {
        query = query.eq('estado', 'activo');
      }
      return await query.order('fecha_asignacion', ascending: false).limit(1).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  String _buildFullName(Map<String, dynamic>? perfil) {
    final parts = <String>[
      _asString(perfil?['nombre']) ?? '',
      _asString(perfil?['apellido_paterno']) ?? '',
      _asString(perfil?['apellido_materno']) ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Paciente' : parts.join(' ');
  }

  String _buildDoctorName(
    Map<String, dynamic>? doctorProfile,
    Map<String, dynamic>? doctorData,
  ) {
    final profileParts = <String>[
      _asString(doctorProfile?['nombre']) ?? '',
      _asString(doctorProfile?['apellido_paterno']) ?? '',
      _asString(doctorProfile?['apellido_materno']) ?? '',
    ].where((part) => part.trim().isNotEmpty).toList();

    if (profileParts.isNotEmpty) {
      return 'Dr. ${profileParts.join(' ')}';
    }

    final directName = _asString(doctorData?['nombre_completo']) ??
        _asString(doctorData?['nombre']) ??
        _asString(doctorData?['medico']);
    if (directName != null) {
      return directName.startsWith('Dr.') ? directName : 'Dr. $directName';
    }

    return 'Sin médico asignado';
  }

  String _summarizeTreatment(Map<String, dynamic> row) {
    final name = _asString(row['medicamento']) ?? 'Medicamento';
    final dose = _asString(row['dosis']) ?? _asString(row['cantidad']) ?? '';
    final freq = _asString(row['frecuencia']) ?? '';
    final parts = <String>[name, if (dose.isNotEmpty) dose, if (freq.isNotEmpty) freq];
    return parts.join(' · ');
  }

  String _formatGlucoseRow(Map<String, dynamic>? row) {
    if (row == null) return 'Sin registro';
    final value = _asNum(row['valor']) ?? _asNum(row['value']);
    final dateLabel = _formatDateLabel(row['fecha']);
    if (value == null) return 'Sin dato · $dateLabel';
    final formatted = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    return '$formatted mg/dL · $dateLabel';
  }

  String _formatPressureRow(Map<String, dynamic>? row) {
    if (row == null) return 'Sin registro';
    final systolic = _asNum(row['sistolica']) ?? _asNum(row['systolic']);
    final diastolic = _asNum(row['diastolica']) ?? _asNum(row['diastolic']);
    final dateLabel = _formatDateLabel(row['fecha']);
    if (systolic == null || diastolic == null) return 'Sin dato · $dateLabel';
    return '${systolic.toInt()}/${diastolic.toInt()} mmHg · $dateLabel';
  }

  String _latestDate(List<Map<String, dynamic>?> rows) {
    DateTime? latest;
    for (final row in rows) {
      final parsed = _parseDate(row?['fecha']);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }
    if (latest == null) return 'Sin fecha';
    return _formatDateLabel(latest.toIso8601String());
  }

  List<List<String>> _buildGlucoseHistoryRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const <List<String>>[
        <String>['Sin registros', 'No hay mediciones de glucosa disponibles.'],
      ];
    }

    return rows.take(10).map((row) {
      final date = _formatDateLabel(row['fecha']);
      final value = _asNum(row['valor']) ?? _asNum(row['value']);
      final source = _asString(row['origen']);
      final reading = value == null
          ? 'Sin dato'
          : '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} mg/dL';
      final suffix = source == null ? '' : ' · $source';
      return <String>[date, '$reading$suffix'];
    }).toList();
  }

  List<List<String>> _buildPressureHistoryRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const <List<String>>[
        <String>['Sin registros', 'No hay mediciones de presión disponibles.'],
      ];
    }

    return rows.take(10).map((row) {
      final date = _formatDateLabel(row['fecha']);
      final sys = _asNum(row['sistolica']) ?? _asNum(row['systolic']);
      final dia = _asNum(row['diastolica']) ?? _asNum(row['diastolic']);
      final pulse = _asNum(row['frecuencia']) ?? _asNum(row['pulso']);
      final reading = (sys == null || dia == null)
          ? 'Sin dato'
          : '${sys.toInt()}/${dia.toInt()} mmHg';
      final suffix = pulse == null ? '' : ' · Pulso ${pulse.toInt()} lpm';
      return <String>[date, '$reading$suffix'];
    }).toList();
  }

  List<List<String>> _buildAdherenceRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const <List<String>>[
        <String>['Sin adherencia', 'No hay datos de adherencia de tratamientos.'],
      ];
    }

    return rows.take(10).map((row) {
      final name = _asString(row['medicamento']) ?? _asString(row['nombre']) ?? 'Tratamiento';
      final expected = _asInt(row['dosis_esperadas']) ?? _asInt(row['dosis_programadas']) ?? _asInt(row['esperadas']) ?? 0;
      final taken = _asInt(row['dosis_tomadas']) ?? _asInt(row['tomadas']) ?? 0;
      final missed = _asInt(row['dosis_falladas']) ?? _asInt(row['falladas']) ?? ((expected - taken) < 0 ? 0 : (expected - taken));
      final explicitPercent = _asNum(row['porcentaje_adherencia']) ?? _asNum(row['adherencia']);

      final percent = explicitPercent ?? (expected > 0 ? (taken * 100 / expected) : null);
      final percentLabel = percent == null ? '--%' : '${percent.round()}%';

      return <String>[
        name,
        'Tomadas $taken/$expected · Falladas $missed · Adherencia $percentLabel',
      ];
    }).toList();
  }

  num? _asNum(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  int? _asInt(Object? value) {
    final number = _asNum(value);
    return number?.toInt();
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
    if (date == null) return 'Sin fecha';

    final now = DateTime.now();
    final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (sameDay) {
      return 'Hoy $hour:$minute';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
    if (isYesterday) {
      return 'Ayer $hour:$minute';
    }

    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hasHadBirthday =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthday) age--;
    return age;
  }

  Future<void> _generateAndSaveDocument() async {
    if (_isLoading) {
      return;
    }

    if (_isExporting) {
      return;
    }

    setState(() => _isExporting = true);

    try {
      final payload = jsonEncode(<String, dynamic>{
        'identificationRows': _pdfIdentificationRows,
        'medicalRows': _pdfMedicalRows,
        'followupRows': _pdfFollowupRows,
        'glucoseHistoryRows': _pdfGlucoseHistoryRows,
        'pressureHistoryRows': _pdfPressureHistoryRows,
        'adherenceRows': _pdfAdherenceRows,
      });
      final bytes = await compute(_buildMedicalHistoryPdfBytes, payload);
      final safeName = _patientName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
        final now = DateTime.now();
        final stamp =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';
        final fileName = safeName.isEmpty
          ? 'historial_medico_$stamp.pdf'
          : 'historial_medico_${safeName}_$stamp.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento generado. Puedes guardarlo o compartirlo desde el panel del sistema.'),
        ),
      );
    } on MissingPluginException catch (error) {
      debugPrint('Plugin faltante al generar historial medico: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reinicia la app completamente para activar la exportacion del documento.'),
        ),
      );
    } catch (error) {
      debugPrint('Error al generar historial medico: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el historial médico.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.prussianBlue),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Historial médico',
          style: TextStyle(
            color: AppColors.prussianBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMedicalHistory,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      _loadError!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(15, 23, 42, 0.05),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CLINIK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Resumen clínico del paciente',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.prussianBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Actualizado: $_latestUpdate',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),
                    const Text(
                      'Datos de identificación',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow('Nombre', _patientName),
                    _buildDataRow('Edad', _ageText),
                    _buildDataRow('CURP', _curpText),
                    _buildDataRow('NSS', _nssText),
                    const SizedBox(height: 18),
                    const Text(
                      'Información médica',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow('Diagnósticos', _diagnosesText),
                    _buildDataRow('Médico tratante', _doctorName),
                    _buildDataRow('Centro de salud', _centerName),
                    _buildDataRow('Medicamento actual', _currentMedication),
                    const SizedBox(height: 18),
                    const Text(
                      'Lecturas y seguimiento',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow('Glucosa reciente', _latestGlucose),
                    _buildDataRow('Presión reciente', _latestPressure),
                    _buildDataRow('Última actualización', _latestUpdate),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.aliceBlue.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'El documento incluye resumen clínico, últimas lecturas y detalle de los 10 registros más recientes de glucosa/presión, junto con adherencia de tratamientos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.prussianBlue,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _generateAndSaveDocument,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _isExporting ? 'Generando...' : 'Generar documento',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

  Widget _buildDataRow(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 340;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: useVerticalLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.prussianBlue,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.prussianBlue,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

Future<Uint8List> _buildMedicalHistoryPdfBytes(String payloadJson) async {
  final decoded = jsonDecode(payloadJson) as Map<String, dynamic>;
  final identificationRows = _parsePdfRows(decoded['identificationRows']);
  final medicalRows = _parsePdfRows(decoded['medicalRows']);
  final followupRows = _parsePdfRows(decoded['followupRows']);
  final glucoseHistoryRows = _parsePdfRows(decoded['glucoseHistoryRows']);
  final pressureHistoryRows = _parsePdfRows(decoded['pressureHistoryRows']);
  final adherenceRows = _parsePdfRows(decoded['adherenceRows']);

  final document = pw.Document();
  final generatedAt = DateTime.now();

  // Mapeo exacto de AppColors a PdfColor
  final primaryColor = PdfColor.fromHex('0D9488');
  final prussianBlueColor = PdfColor.fromHex('0F172A');
  final backgroundColor = PdfColor.fromHex('F8FAFC');
  final aliceBlueColor = PdfColor.fromHex('E0F2FE');
  final stableColor = PdfColor.fromHex('10B981');
  final borderSoftColor = PdfColor.fromHex('CBD5E1');

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      header: (context) {
        if (context.pageNumber == 1) return pw.SizedBox();
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: borderSoftColor, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CLINIK - Expediente Clinico del Paciente',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: prussianBlueColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Pagina ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: prussianBlueColor),
              ),
            ],
          ),
        );
      },
      footer: (context) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: borderSoftColor, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Documento medico confidencial expedido por CLINIK System.',
                style: pw.TextStyle(fontSize: 8, color: prussianBlueColor),
              ),
              pw.Text(
                'Emitido: ${_formatPdfDate(generatedAt)}',
                style: pw.TextStyle(fontSize: 8, color: prussianBlueColor),
              ),
            ],
          ),
        );
      },
      build: (context) => [
        // 1. Banner principal
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: prussianBlueColor,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'CLINIK',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'EXPEDIENTE MEDICO DIGITAL',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          letterSpacing: 1.2,
                          color: aliceBlueColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Historial Medico del Paciente',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Fecha de emision',
                    style: pw.TextStyle(fontSize: 8, color: aliceBlueColor),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _formatPdfDate(generatedAt),
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // 2. Tarjetas de datos
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 1,
              child: _buildPdfCard(
                title: 'Datos de Identificacion',
                accentColor: primaryColor,
                textColor: prussianBlueColor,
                rows: identificationRows,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 1,
              child: _buildPdfCard(
                title: 'Informacion Medica',
                accentColor: primaryColor,
                textColor: prussianBlueColor,
                rows: medicalRows,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),

        // 3. Resumen reciente
        _buildPdfCard(
          title: 'Resumen Reciente de Signos Vitales',
          accentColor: stableColor,
          textColor: prussianBlueColor,
          cardBg: aliceBlueColor,
          rows: followupRows,
          isHorizontal: true,
        ),
        pw.SizedBox(height: 14),

        // 4. Titulo historicos
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 2, bottom: 6),
          child: pw.Text(
            'REGISTROS HISTORICOS Y SEGUIMIENTO',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: prussianBlueColor,
              letterSpacing: 0.8,
            ),
          ),
        ),

        // 5. Tablas lado a lado
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _buildPdfTableSection(
                title: 'Ultimas 10 Lecturas de Glucosa',
                headers: const ['Fecha y Hora', 'Valor / Origen'],
                rows: glucoseHistoryRows,
                headerColor: aliceBlueColor,
                borderColor: borderSoftColor,
                textColor: prussianBlueColor,
                altRowBg: backgroundColor,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildPdfTableSection(
                title: 'Ultimas 10 Lecturas de Presion',
                headers: const ['Fecha y Hora', 'Medicion / Pulso'],
                rows: pressureHistoryRows,
                headerColor: aliceBlueColor,
                borderColor: borderSoftColor,
                textColor: prussianBlueColor,
                altRowBg: backgroundColor,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),

        // 6. Tabla adherencia
        _buildPdfTableSection(
          title: 'Adherencia y Cumplimiento de Tratamientos',
          headers: const ['Tratamiento / Medicamento', 'Detalle de Tomas / % Adherencia'],
          rows: adherenceRows,
          headerColor: aliceBlueColor,
          borderColor: borderSoftColor,
          textColor: prussianBlueColor,
          altRowBg: backgroundColor,
        ),
      ],
    ),
  );

  return document.save();
}

// Widget auxiliar para tarjetas
pw.Widget _buildPdfCard({
  required String title,
  required PdfColor accentColor,
  required PdfColor textColor,
  required List<List<String>> rows,
  PdfColor? cardBg,
  bool isHorizontal = false,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: cardBg ?? PdfColors.white,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: PdfColor.fromHex('CBD5E1'), width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 12,
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        if (isHorizontal)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: rows.map((row) {
              return pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        row.isNotEmpty ? row[0] : '',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColor.fromHex('64748B'),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        row.length > 1 ? row[1] : '',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        if (!isHorizontal)
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 80,
                    child: pw.Text(
                      row.isNotEmpty ? row[0] : '',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('64748B'),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      row.length > 1 ? row[1] : '',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: textColor,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

// Widget auxiliar para tablas
pw.Widget _buildPdfTableSection({
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
  required PdfColor headerColor,
  required PdfColor borderColor,
  required PdfColor textColor,
  PdfColor? altRowBg,
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: borderColor, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: headerColor,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(9),
              topRight: pw.Radius.circular(9),
            ),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(
              color: PdfColor.fromHex('E2E8F0'),
              width: 0.5,
            ),
          ),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
              children: headers.map((header) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: pw.Text(
                    header,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                );
              }).toList(),
            ),
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final isEven = index % 2 == 0;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: isEven ? PdfColors.white : (altRowBg ?? PdfColor.fromHex('F8FAFC')),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: pw.Text(
                      row.isNotEmpty ? row[0] : '',
                      style: pw.TextStyle(fontSize: 8, color: textColor),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: pw.Text(
                      row.length > 1 ? row[1] : '',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    ),
  );
}

String _formatPdfDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

List<List<String>> _parsePdfRows(dynamic rawRows) {
  if (rawRows is! List) return const <List<String>>[];

  final rows = <List<String>>[];
  for (final row in rawRows) {
    if (row is List && row.length >= 2) {
      final key = row[0].toString();
      final value = row[1].toString();
      rows.add(<String>[key, value]);
    }
  }

  return rows;
}