import 'package:clinik/core/app_colors.dart';
import 'package:clinik/core/supabase_services.dart';
import 'package:clinik/screens/medical_history_screen.dart';
import 'package:clinik/widgets/medical_chat_floating_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Map<int, String> _municipioFallbackById = {
    1: 'Morelia',
    13: 'Morelia',
    14: 'Uruapan',
    15: 'Zamora',
    16: 'Maravatio',
    17: 'Patzcuaro',
    18: 'Zitacuaro',
  };

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _curpController = TextEditingController();
  final TextEditingController _nssController = TextEditingController();

  bool _notificationsEnabled = true;
  bool _medRemindersEnabled = true;
  bool _apptRemindersEnabled = true;
  bool _isSigningOut = false;
  bool _isLoadingProfile = true;
  bool _isSavingMedicalData = false;

  String? _profileError;
  String _patientName = 'Paciente';
  String _patientSubtitle = 'Paciente con monitoreo activo';
  String _syncStatus = 'Expediente digital sincronizado';
  String _ageText = '-- años';
  String _birthText = 'Sin fecha';
  String _sexText = 'No registrado';
  String _municipalityText = 'No registrado';
  String _doctorName = 'Sin médico asignado';
  String _doctorDetails = '';
  String _centerText = 'Sin centro de salud';
  String _emergencyContactText = 'No registrado';
  String _phoneText = '';

  List<String> _diagnoses = <String>[];
  List<String> _treatmentSummaries = <String>[];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _curpController.dispose();
    _nssController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _profileError = 'No hay una sesión activa.';
        _isLoadingProfile = false;
      });
      return;
    }

    try {
      final perfil = await _supabase
          .from('perfiles')
          .select()
          .eq('id_usuario', userId)
          .maybeSingle();

      final paciente = await _supabase
          .from('pacientes')
          .select()
          .eq('id_usuario', userId)
          .maybeSingle();

      final pacienteId = paciente?['id_paciente'];
      final municipioRef =
          paciente?['id_municipio'] ??
          paciente?['municipio_id'] ??
          paciente?['id_municipios'] ??
          paciente?['municipio'] ??
          paciente?['nombre_municipio'];
      final doctorRef = paciente?['id_medico'] ?? paciente?['medico_id'];

      final municipioName = await _loadMunicipioName(municipioRef);

      final diagnoses = await _loadPatientDiseases(
        patientId: pacienteId,
        patientUserId: userId,
        patientData: paciente,
      );
      final treatments = pacienteId == null
          ? <String>[]
          : await _loadPatientTreatments(pacienteId);

      final doctorContext = pacienteId == null
          ? null
          : await _loadDoctorContext(
              patientId: pacienteId,
              patientUserId: userId,
              doctorRef: doctorRef,
            );

      final doctorData = doctorContext?['doctorData'] as Map<String, dynamic>?;
      final doctorProfile =
          doctorContext?['doctorProfile'] as Map<String, dynamic>?;
      final centerFromContext = _asString(doctorContext?['centerName']);

      final birthDate = DateTime.tryParse(
        _asString(paciente?['nacimiento']) ?? '',
      );

      if (!mounted) return;

      setState(() {
        _patientName = _buildFullName(perfil);
        _patientSubtitle = _roleLabelFromProfile(perfil);
        _syncStatus = 'Expediente actualizado';
        _ageText = birthDate == null
            ? '-- años'
            : '${_calculateAge(birthDate)} años';
        _birthText = birthDate == null
            ? 'Sin fecha'
            : _formatBirthDate(birthDate);
        _sexText = _asString(paciente?['sexo']) ?? 'No registrado';
        _municipalityText = municipioName ?? 'No registrado';
        _doctorName = _buildDoctorName(doctorProfile, doctorData);
        _doctorDetails = [
          _asString(doctorData?['especialidad']) ?? '',
          _asString(doctorData?['institucion']) ??
              _asString(doctorData?['centro_medico']) ??
              _asString(doctorData?['centro_salud']) ??
              '',
        ].where((value) => value.trim().isNotEmpty).join(' · ');
        _centerText =
            centerFromContext ??
            _asString(doctorData?['institucion']) ??
            _asString(doctorData?['centro_medico']) ??
            _asString(doctorData?['centro_salud']) ??
            'Sin centro de salud';
        _emergencyContactText =
            _asString(paciente?['contacto_emergencia']) ?? 'No registrado';
        _phoneText = _asString(perfil?['telefono']) ?? '';
        _curpController.text = _asString(paciente?['CURP']) ?? '';
        _nssController.text =
            _asString(paciente?['Numero_Seguro_Social']) ?? '';
        _diagnoses = diagnoses;
        _treatmentSummaries = treatments;
        _profileError = null;
        _isLoadingProfile = false;
      });
    } catch (error) {
      debugPrint('Error al cargar perfil: $error');
      if (!mounted) return;
      setState(() {
        _profileError = 'No se pudo sincronizar la información del perfil.';
        _isLoadingProfile = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _loadDoctorContext({
    required dynamic patientId,
    required String patientUserId,
    dynamic doctorRef,
  }) async {
    Map<String, dynamic>? assignment;
    dynamic doctorId = doctorRef;

    try {
      // Prioriza la asignacion activa del paciente por id_paciente.
      assignment = await _loadLatestAssignmentByPatient(
        patientId: patientId,
        activeOnly: true,
      );
      // Fallback por id_usuario si el esquema de relacion en paciente_medico usa usuario.
      assignment ??= await _loadLatestAssignmentByUser(
        userId: patientUserId,
        activeOnly: true,
      );
      doctorId ??= assignment?['id_medico'];
    } catch (error) {
      debugPrint('No se pudo cargar asignacion activa: $error');
      assignment = null;
    }

    if (assignment == null) {
      try {
        // Fallback: toma la asignacion mas reciente sin filtrar estado.
        assignment = await _loadLatestAssignmentByPatient(
          patientId: patientId,
          activeOnly: false,
        );
        assignment ??= await _loadLatestAssignmentByUser(
          userId: patientUserId,
          activeOnly: false,
        );
        doctorId ??= assignment?['id_medico'];
      } catch (error) {
        debugPrint('No se pudo cargar asignacion reciente: $error');
        assignment = null;
      }
    }

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

    return {
      'doctorData': doctorData,
      'doctorProfile': doctorProfile,
      'centerName': centerName,
    };
  }

  Future<Map<String, dynamic>?> _loadLatestAssignmentByPatient({
    required dynamic patientId,
    required bool activeOnly,
  }) async {
    final candidates = <dynamic>{};
    candidates.add(patientId);

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
        var query = _supabase
            .from('paciente_medico')
            .select()
            .eq('id_paciente', candidate);

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
        // Se intenta con otros tipos de candidate.
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _loadLatestAssignmentByUser({
    required String userId,
    required bool activeOnly,
  }) async {
    try {
      var query = _supabase
          .from('paciente_medico')
          .select()
          .eq('id_usuario', userId);

      if (activeOnly) {
        query = query.eq('estado', 'activo');
      }

      return await query
          .order('fecha_asignacion', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      // Si no existe columna id_usuario o falla RLS, no bloquea la carga.
      return null;
    }
  }

  Future<String?> _loadMunicipioName(dynamic municipioRef) async {
    if (municipioRef == null) {
      return null;
    }

    final refText = municipioRef.toString().trim();
    if (refText.isEmpty) {
      return null;
    }

    // Si ya viene como texto no numérico, lo mostramos tal cual como fallback.
    final looksNumeric = RegExp(r'^\d+$').hasMatch(refText);
    final directNameFallback = looksNumeric ? null : refText;

    try {
      if (looksNumeric) {
        final municipioId = int.tryParse(refText);
        if (municipioId == null) {
          return null;
        }

        final municipio = await _supabase
            .from('municipios')
            .select('nombre')
            .eq('id_municipio', municipioId)
            .maybeSingle();

        final nombre = _asString(municipio?['nombre']);
        if (nombre != null && nombre.isNotEmpty) {
          return nombre;
        }

        return _municipioFallbackById[municipioId];
      }

      final byName = await _supabase
          .from('municipios')
          .select('nombre')
          .eq('nombre', refText)
          .maybeSingle();

      return _asString(byName?['nombre']) ?? directNameFallback;
    } catch (_) {
      debugPrint('No se pudo resolver municipio para referencia: $refText');
      final fallbackId = int.tryParse(refText);
      if (fallbackId != null) {
        return _municipioFallbackById[fallbackId];
      }
      return directNameFallback;
    }
  }

  Future<List<String>> _loadPatientDiseases({
    required dynamic patientId,
    required String patientUserId,
    required Map<String, dynamic>? patientData,
  }) async {
    final names = <String>[];
    final seen = <String>{};

    void addName(String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty) return;
      final key = text.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      names.add(text);
    }

    Future<void> collectFromRows(List<dynamic> rows) async {
      for (final rawRow in rows) {
        if (rawRow is! Map<String, dynamic>) continue;

        final diseaseId = rawRow['id_enfermedad'] ?? rawRow['enfermedad_id'];
        if (diseaseId == null) continue;

        final diseaseName = await _loadDiseaseNameById(diseaseId);
        addName(diseaseName);
      }
    }

    if (patientId != null) {
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
          final rows = await _supabase
              .from('paciente_enfermedades')
              .select('id_enfermedad, fecha_diagnostico, estado, observaciones')
              .eq('id_paciente', candidate)
              .eq('estado', 'activo')
              .order('fecha_diagnostico', ascending: false);
          await collectFromRows(rows);
        } catch (_) {
          // Continua con otros candidatos.
        }
      }
    }

    try {
      final rowsByUser = await _supabase
          .from('paciente_enfermedades')
          .select('id_enfermedad, fecha_diagnostico, estado, observaciones')
          .eq('id_usuario', patientUserId)
          .eq('estado', 'activo')
          .order('fecha_diagnostico', ascending: false);
      await collectFromRows(rowsByUser);
    } catch (_) {
      // Esquema alterno sin id_usuario o sin permisos.
    }

    // Fallback: algunos esquemas guardan el diagnostico directamente en pacientes.
    final directDiagnosis =
        _asString(patientData?['diagnostico']) ??
        _asString(patientData?['diagnosticos']) ??
        _asString(patientData?['enfermedad']) ??
        _asString(patientData?['enfermedades']);
    if (directDiagnosis != null) {
      for (final part in directDiagnosis.split(RegExp(r'[,;|]'))) {
        addName(part);
      }
    }

    return names;
  }

  Future<String?> _loadDiseaseNameById(dynamic diseaseId) async {
    final candidates = <dynamic>{diseaseId};
    final asText = diseaseId.toString().trim();
    if (asText.isNotEmpty) {
      candidates.add(asText);
      final asInt = int.tryParse(asText);
      if (asInt != null) {
        candidates.add(asInt);
      }
    }

    for (final candidate in candidates) {
      try {
        final byPrimaryId = await _supabase
            .from('enfermedades')
            .select('nombre')
            .eq('id_enfermedad', candidate)
            .eq('estado', 'activo')
            .maybeSingle();
        final name = _asString(byPrimaryId?['nombre']);
        if (name != null && name.isNotEmpty) {
          return name;
        }
      } catch (_) {
        // Intenta esquema alterno.
      }

      try {
        final byGenericId = await _supabase
            .from('enfermedades')
            .select('nombre')
            .eq('id', candidate)
            .eq('estado', 'activo')
            .maybeSingle();
        final name = _asString(byGenericId?['nombre']);
        if (name != null && name.isNotEmpty) {
          return name;
        }
      } catch (_) {
        // Continua con otros candidatos.
      }
    }

    return null;
  }

  Future<List<String>> _loadPatientTreatments(dynamic patientId) async {
    final rows = await _supabase
        .from('tratamientos')
        .select('id_medicamento, dosis, frecuencia')
        .eq('id_paciente', patientId)
        .order('fecha_inicio', ascending: false);

    final summaries = <String>[];
    for (final row in rows) {
      final medId = row['id_medicamento'];
      Map<String, dynamic>? medication;
      if (medId != null) {
        medication = await _supabase
            .from('medicamentos')
            .select('nombre, presentacion')
            .eq('id_medicamento', medId)
            .maybeSingle();
      }

      final parts = <String>[
        _asString(medication?['nombre']) ?? 'Medicamento',
        _asString(medication?['presentacion']) ?? '',
        _asString(row['dosis']) ?? '',
        _asString(row['frecuencia']) ?? '',
      ].where((value) => value.trim().isNotEmpty).toList();

      if (parts.isNotEmpty) {
        summaries.add(parts.join(' · '));
      }
    }

    return summaries;
  }

  Future<void> _saveMedicalData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showMessage('No hay una sesión activa.');
      return;
    }

    setState(() => _isSavingMedicalData = true);

    try {
      await _supabase
          .from('pacientes')
          .update({
            'CURP': _curpController.text.trim(),
            'Numero_Seguro_Social': _nssController.text.trim(),
          })
          .eq('id_usuario', userId);

      _showMessage('Datos médicos actualizados.');
    } catch (error) {
      debugPrint('Error al guardar perfil: $error');
      _showMessage('No se pudieron guardar los cambios.');
    } finally {
      if (mounted) {
        setState(() => _isSavingMedicalData = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isSigningOut = true);
    try {
      await SupabaseServices.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No se pudo cerrar sesión. Intenta de nuevo.');
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  String _buildFullName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Paciente';
    final parts = <String>[
      _asString(profile['nombre']) ?? '',
      _asString(profile['apellido_paterno']) ?? '',
      _asString(profile['apellido_materno']) ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Paciente' : parts.join(' ');
  }

  String _buildDoctorName(
    Map<String, dynamic>? doctorProfile,
    Map<String, dynamic>? doctorData,
  ) {
    final fromProfile = _buildFullName(doctorProfile);
    if (fromProfile != 'Paciente') {
      return fromProfile;
    }

    final fromDoctorTable = [
      _asString(doctorData?['nombre']) ?? '',
      _asString(doctorData?['apellido_paterno']) ?? '',
      _asString(doctorData?['apellido_materno']) ?? '',
    ].where((part) => part.isNotEmpty).join(' ');

    if (fromDoctorTable.isNotEmpty) {
      return fromDoctorTable;
    }

    return 'Sin médico asignado';
  }

  String _roleLabelFromProfile(Map<String, dynamic>? profile) {
    final role = (_asString(profile?['rol']) ?? 'paciente').toLowerCase();
    return role == 'medico'
        ? 'Médico con acceso activo'
        : 'Paciente con monitoreo activo';
  }

  String? _asString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hadBirthday =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) age -= 1;
    return age < 0 ? 0 : age;
  }

  String _formatBirthDate(DateTime birthDate) {
    final day = birthDate.day.toString().padLeft(2, '0');
    final month = birthDate.month.toString().padLeft(2, '0');
    return '$day/$month/${birthDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const MedicalChatFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfileData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: _isLoadingProfile
                ? const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mi perfil',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.prussianBlue,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_none_outlined,
                              size: 28,
                            ),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/medical-followup',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_profileError != null)
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
                            _profileError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      _buildIdentityCard(),
                      const SizedBox(height: 24),
                      _buildMedicalSection(),
                      const SizedBox(height: 24),
                      _buildPreferencesSection(),
                      const SizedBox(height: 24),
                      _buildSecuritySection(),
                      const SizedBox(height: 28),
                      _buildSignOutButton(),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'CLINIK v1.0.0 · Versión Hackathon 2026',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.aliceBlue,
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.stable,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _patientName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.prussianBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.aliceBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _patientSubtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sync, size: 14, color: AppColors.stable),
              const SizedBox(width: 6),
              Text(
                _syncStatus,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.stable,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mi información médica',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.prussianBlue,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: Icons.cake_outlined,
                title: 'Edad',
                value: _ageText,
              ),
              const Divider(height: 20),
              _buildInfoRow(
                icon: Icons.event_outlined,
                title: 'Nacimiento',
                value: _birthText,
              ),
              const Divider(height: 20),
              _buildInfoRow(
                icon: Icons.wc_outlined,
                title: 'Sexo',
                value: _sexText,
              ),
              const Divider(height: 20),
              _buildInfoRow(
                icon: Icons.location_city_outlined,
                title: 'Municipio',
                value: _municipalityText,
              ),
              const Divider(height: 20),
              _buildInfoRow(
                icon: Icons.phone_outlined,
                title: 'Teléfono',
                value: _phoneText.isEmpty ? 'No registrado' : _phoneText,
              ),
              const Divider(height: 20),
              _buildMedicalInputField(
                icon: Icons.badge_outlined,
                label: 'CURP (México)',
                controller: _curpController,
                hintText: 'Ej. GODE561231HDFRRN09',
                maxLength: 18,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                ],
              ),
              const SizedBox(height: 10),
              _buildMedicalInputField(
                icon: Icons.numbers,
                label: 'NSS (México)',
                controller: _nssController,
                hintText: 'Ej. 12345678901',
                maxLength: 11,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity),
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _diagnoses.isEmpty
                      ? [_buildTag('Sin diagnósticos activos')]
                      : _diagnoses.map(_buildTag).toList(),
                ),
              ),
              const Divider(height: 20),
              _buildInfoRow(
                icon: Icons.local_hospital_outlined,
                title: 'Centro médico',
                value: _centerText,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                icon: Icons.person_outline,
                title: 'Médico',
                value: _doctorDetails.isEmpty
                    ? _doctorName
                    : '$_doctorName · $_doctorDetails',
              ),
              if (_treatmentSummaries.isNotEmpty) ...[
                const Divider(height: 20),
                _buildInfoRow(
                  icon: Icons.medication_outlined,
                  title: 'Tratamiento',
                  value: _treatmentSummaries.first,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicalHistoryScreen(
                          curp: _curpController.text.trim(),
                          nss: _nssController.text.trim(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text(
                    'Generar historial médico',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.prussianBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferencias y recordatorios',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.prussianBlue,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              Material(
                color: Colors.white,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Notificaciones generales',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  value: _notificationsEnabled,
                  onChanged: (val) => setState(() => _notificationsEnabled = val),
                ),
              ),
              const Divider(height: 12),
              Material(
                color: Colors.white,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Recordatorios de medicamentos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        _buildTimeChip('08:00'),
                        _buildTimeChip('14:00'),
                        _buildTimeChip('20:00'),
                      ],
                    ),
                  ),
                  value: _medRemindersEnabled,
                  onChanged: (val) => setState(() => _medRemindersEnabled = val),
                ),
              ),
              const Divider(height: 12),
              Material(
                color: Colors.white,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Recordatorios de citas médicas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.prussianBlue,
                    ),
                  ),
                  subtitle: const Text(
                    'Aviso 24 hrs antes',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: _apptRemindersEnabled,
                  onChanged: (val) => setState(() => _apptRemindersEnabled = val),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Soporte y seguridad',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.prussianBlue,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: Icons.phone_in_talk,
                title: 'Contacto emergencia',
                value: _emergencyContactText,
              ),
              const Divider(height: 20),
              const Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.lock_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: Text(
                    'Privacidad y protección de datos',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  subtitle: Text(
                    'Cumplimiento NOM e información protegida',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ),
              const Divider(height: 12),
              const Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.fingerprint,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: Text(
                    'Cambiar PIN / Acceso biométrico',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.critical, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isSigningOut ? null : _handleSignOut,
        icon: const Icon(Icons.logout, color: AppColors.critical),
        label: _isSigningOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.critical,
                ),
              )
            : const Text(
                'Cerrar sesión',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.critical,
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.prussianBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.aliceBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildTimeChip(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        time,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.prussianBlue,
        ),
      ),
    );
  }

  Widget _buildMedicalInputField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hintText,
    required int maxLength,
    required TextInputType keyboardType,
    required List<TextInputFormatter> inputFormatters,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(maxLength),
                  ...inputFormatters,
                ],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.prussianBlue,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                  isDense: true,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
