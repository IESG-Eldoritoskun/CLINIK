import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_colors.dart';
import '../core/gemini_health_service.dart';

class AiHealthAnalysisScreen extends StatefulWidget {
  const AiHealthAnalysisScreen({super.key});

  @override
  State<AiHealthAnalysisScreen> createState() => _AiHealthAnalysisScreenState();
}

class _AiHealthAnalysisScreenState extends State<AiHealthAnalysisScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GeminiHealthService _gemini = GeminiHealthService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const String _chatStoragePrefix = 'ai_health_chat_v1_';

  bool _isLoadingContext = true;
  bool _isSending = false;
  String? _currentUserId;

  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _ultimaGlucosa;
  Map<String, dynamic>? _ultimaPresion;
  List<Map<String, dynamic>> _medicationRows = <Map<String, dynamic>>[];

  final List<_ChatMessage> _messages = <_ChatMessage>[];

  static const Set<String> _analysisHeadings = <String>{
    'PANORAMA GENERAL',
    'HALLAZGOS CLAVE',
    'RIESGOS Y ALERTAS',
    'PLAN DE ACCION PARA HOY',
    'SEGUIMIENTO RECOMENDADO',
  };

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _currentUserId = null;
      if (!mounted) return;
      setState(() {
        _isLoadingContext = false;
        _messages.add(
          const _ChatMessage.assistant(
            'No encontré una sesión activa. Inicia sesión para usar el asistente clínico.',
          ),
        );
      });
      return;
    }

    _currentUserId = userId;
    final restoredMessages = await _restoreChatHistory(userId);

    try {
      final paciente = await _supabase
          .from('pacientes')
          .select('id_paciente')
          .eq('id_usuario', userId)
          .maybeSingle();

      final patientId = paciente?['id_paciente'];

        final Future<Map<String, dynamic>?> perfilFuture = _supabase
          .from('perfiles')
          .select()
          .eq('id_usuario', userId)
          .maybeSingle()
          .then((value) => value);

        final Future<Map<String, dynamic>?> glucosaFuture = patientId == null
          ? Future.value(null)
          : _supabase
              .from('mediciones')
              .select()
              .eq('id_paciente', patientId)
              .eq('tipo', 'glucosa')
              .order('fecha', ascending: false)
              .limit(1)
            .maybeSingle()
            .then((value) => value);

        final Future<Map<String, dynamic>?> presionFuture = patientId == null
          ? Future.value(null)
          : _supabase
              .from('presiones_arteriales')
              .select()
              .eq('id_paciente', patientId)
              .order('fecha', ascending: false)
              .limit(1)
              .maybeSingle()
              .then((value) => value);

      final Future<List<dynamic>> medsFuture = patientId == null
          ? Future.value(<dynamic>[])
          : _supabase
              .from('vista_adherencia_tratamientos')
              .select('medicamento, frecuencia, dosis_esperadas, dosis_tomadas, dosis_falladas')
              .eq('id_paciente', patientId)
              .limit(5)
              .then((value) => value);

      final results = await Future.wait<dynamic>([
        perfilFuture,
        glucosaFuture,
        presionFuture,
        medsFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _perfil = results[0] as Map<String, dynamic>?;
        _ultimaGlucosa = results[1] as Map<String, dynamic>?;
        _ultimaPresion = results[2] as Map<String, dynamic>?;
        _medicationRows = List<Map<String, dynamic>>.from(results[3] as List);
        _messages
          ..clear()
          ..addAll(restoredMessages);
        _isLoadingContext = false;
      });

      if (restoredMessages.isEmpty) {
        _seedWelcomeMessage();
      } else {
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingContext = false;
        _messages
          ..clear()
          ..addAll(restoredMessages);
        if (_messages.isEmpty) {
          _messages.add(
            _ChatMessage.assistant(
              'No pude cargar tu contexto clínico (${error.toString()}). Aun así puedes hacer preguntas generales.',
            ),
          );
        }
      });
    }
  }

  Future<List<_ChatMessage>> _restoreChatHistory(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_chatStoragePrefix$userId');
      if (raw == null || raw.trim().isEmpty) {
        return <_ChatMessage>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <_ChatMessage>[];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_ChatMessage.fromJson)
          .toList();
    } catch (_) {
      return <_ChatMessage>[];
    }
  }

  Future<void> _persistChatHistory() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final capped = _messages.length > 80
        ? _messages.sublist(_messages.length - 80)
        : List<_ChatMessage>.from(_messages);
    final payload = jsonEncode(capped.map((m) => m.toJson()).toList());
    await prefs.setString('$_chatStoragePrefix$userId', payload);
  }

  Future<void> _clearPersistedChatHistory() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_chatStoragePrefix$userId');
  }

  void _persistChatHistoryFireAndForget() {
    _persistChatHistory();
  }

  Future<void> _confirmAndClearConversation() async {
    if (_isSending) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppColors.aliceBlue.withValues(alpha: 0.9)),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: AppColors.critical, size: 22),
              SizedBox(width: 8),
              Text(
                'Borrar conversacion',
                style: TextStyle(
                  color: AppColors.prussianBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: const Text(
            'Se eliminaran todos los mensajes de este chat en tu dispositivo. Esta accion no se puede deshacer.',
            style: TextStyle(
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.critical,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Borrar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !mounted) return;

    await _clearPersistedChatHistory();
    if (!mounted) return;

    setState(() {
      _messages.clear();
      _inputController.clear();
    });

    _seedWelcomeMessage();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conversacion borrada correctamente.'),
      ),
    );
  }

  void _seedWelcomeMessage() {
    final name = _patientName;
    final glucosa = _metricLabel(_ultimaGlucosa, glucose: true);
    final presion = _metricLabel(_ultimaPresion, glucose: false);

    final initial =
        'Hola $name. Soy tu asistente de salud. Revisé tu información más reciente: glucosa $glucosa y presión $presion. '
        'Puedo explicarte tus datos, ayudarte a priorizar acciones hoy y resolver dudas de tratamiento de forma clara.';

    setState(() {
      _messages.add(_ChatMessage.assistant(initial));
    });
    _persistChatHistoryFireAndForget();
  }

  String get _patientName {
    final name = (_perfil?['nombre'] as String?)?.trim();
    return (name == null || name.isEmpty) ? 'paciente' : name;
  }

  String _metricLabel(Map<String, dynamic>? row, {required bool glucose}) {
    if (row == null) return 'sin registro reciente';

    if (glucose) {
      final value = _asNum(row['valor']) ?? _asNum(row['value']);
      if (value == null) return 'sin dato';
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} mg/dL';
    }

    final sys = _asNum(row['sistolica']) ?? _asNum(row['systolic']);
    final dia = _asNum(row['diastolica']) ?? _asNum(row['diastolic']);
    if (sys == null || dia == null) return 'sin dato';
    return '${sys.toInt()}/${dia.toInt()} mmHg';
  }

  num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  Future<void> _requestAssistantReply({
    required String message,
    bool addUserBubble = true,
    _ChatMessageKind assistantKind = _ChatMessageKind.chat,
  }) async {
    final text = message.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      if (addUserBubble) {
        _messages.add(_ChatMessage.user(text));
      }
      _isSending = true;
    });
    _persistChatHistoryFireAndForget();
    _scrollToBottom();

    try {
      final reply = await _gemini.generateHealthReply(
        patientName: _patientName,
        clinicalContext: _buildClinicalContext(),
        userMessage: text,
        recentTurns: _recentTurns(),
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage.assistant(reply, kind: assistantKind),
        );
        _isSending = false;
      });
      _persistChatHistoryFireAndForget();
    } on GeminiConfigException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage.assistant(
            '${error.message}.\n\nTip: en desarrollo usa --dart-define=GEMINI_API_KEY=TU_CLAVE',
            isWarning: true,
          ),
        );
        _isSending = false;
      });
      _persistChatHistoryFireAndForget();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage.assistant(
            'No pude generar respuesta en este momento. Error: ${error.toString()}',
            isWarning: true,
          ),
        );
        _isSending = false;
      });
      _persistChatHistoryFireAndForget();
    }

    _scrollToBottom();
  }

  Future<void> _runGeneralAnalysis() async {
    const instruction =
        'Genera un analisis general integral de mi estado de salud segun mi contexto clinico actual. '
        'Quiero una respuesta mas profunda y explicativa que una respuesta normal de chat. '
        'Estructura exactamente en cinco secciones y con estos titulos: '
        'PANORAMA GENERAL, HALLAZGOS CLAVE, RIESGOS Y ALERTAS, PLAN DE ACCION PARA HOY, SEGUIMIENTO RECOMENDADO. '
        'En cada seccion explica con detalle practico y orientado al paciente. '
        'No uses markdown ni asteriscos.';
    await _requestAssistantReply(
      message: instruction,
      addUserBubble: false,
      assistantKind: _ChatMessageKind.generalAnalysis,
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    await _requestAssistantReply(message: text, addUserBubble: true);
  }

  List<String> _recentTurns() {
    final start = _messages.length > 6 ? _messages.length - 6 : 0;
    return _messages
        .skip(start)
        .map((m) => '${m.isUser ? 'Paciente' : 'Asistente'}: ${m.text}')
        .toList();
  }

  String _buildClinicalContext() {
    final buffer = StringBuffer();

    buffer.writeln('Paciente: $_patientName');
    buffer.writeln('Glucosa reciente: ${_metricLabel(_ultimaGlucosa, glucose: true)}');
    buffer.writeln('Presion reciente: ${_metricLabel(_ultimaPresion, glucose: false)}');

    if (_medicationRows.isEmpty) {
      buffer.writeln('Tratamientos: sin datos de adherencia.');
    } else {
      buffer.writeln('Tratamientos y adherencia:');
      for (final row in _medicationRows) {
        final name = (row['medicamento']?.toString().trim().isEmpty ?? true)
            ? 'Medicamento'
            : row['medicamento'].toString().trim();
        final freq = row['frecuencia']?.toString().trim() ?? 'Sin frecuencia';
        final exp = row['dosis_esperadas']?.toString() ?? '0';
        final took = row['dosis_tomadas']?.toString() ?? '0';
        final missed = row['dosis_falladas']?.toString() ?? '0';
        buffer.writeln('- $name, $freq, esperadas: $exp, tomadas: $took, falladas: $missed');
      }
    }

    buffer.writeln('Regla de seguridad: recomendaciones orientativas, no diagnostico definitivo.');
    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Asistente IA de Salud',
          style: TextStyle(
            color: AppColors.prussianBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Borrar conversacion',
            onPressed: _isLoadingContext ? null : _confirmAndClearConversation,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F7F8), Color(0xFFF7F9FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildHeaderCard(),
            _buildDisclaimerCard(),
            _buildGeneralAnalysisButton(),
            Expanded(
              child: _isLoadingContext
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isSending && index == _messages.length) {
                          return _buildTypingBubble();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.health_and_safety_outlined, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Asistente empatico y explicativo. Te orienta con tus datos clinicos en un lenguaje claro y accionable.',
              style: TextStyle(color: Colors.white, fontSize: 12.4, height: 1.36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Color(0xFF9A3412),
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Aviso importante: este asistente puede cometer errores y su contenido es solo orientativo. No sustituye la valoracion, el diagnostico ni el tratamiento indicados por un profesional de la salud.',
              style: TextStyle(
                color: Color(0xFF7C2D12),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralAnalysisButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: FilledButton.icon(
        onPressed: (_isLoadingContext || _isSending) ? null : _runGeneralAnalysis,
        icon: const Icon(Icons.insights_outlined),
        label: const Text('Generar analisis general'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0B8A82),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    if (!message.isUser && message.kindOrDefault == _ChatMessageKind.generalAnalysis) {
      return _buildGeneralAnalysisBubble(message.text);
    }

    final isUser = message.isUser;
    final isWarning = message.isWarning;

    final textColor = isUser
        ? Colors.white
        : (isWarning ? const Color(0xFF8A360F) : const Color(0xFF0F172A));

    final bubbleDecoration = isUser
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B9F97), Color(0xFF0F8B84)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B9F97).withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: isWarning ? const Color(0xFFFFF7ED) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(
              color: isWarning ? const Color(0xFFFED7AA) : const Color(0xFFE3EAF0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isWarning ? Icons.error_outline : Icons.smart_toy_outlined,
                      size: 14,
                      color: isWarning ? const Color(0xFF9A3412) : const Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isWarning ? 'Asistente IA (aviso)' : 'Asistente IA',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isWarning ? const Color(0xFF9A3412) : const Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: bubbleDecoration,
              child: _buildPrettyMessageText(
                message.text,
                textColor: textColor,
                emphasizeSections: !isUser,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrettyMessageText(
    String text, {
    required Color textColor,
    bool emphasizeSections = false,
  }) {
    final lines = text
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          _buildPrettyLine(
            lines[i].trim(),
            textColor: textColor,
            emphasizeSections: emphasizeSections,
          ),
          if (i != lines.length - 1) const SizedBox(height: 3),
        ],
      ],
    );
  }

  Widget _buildPrettyLine(
    String line, {
    required Color textColor,
    required bool emphasizeSections,
  }) {
    final upper = line.toUpperCase();
    final isAnalysisHeading = emphasizeSections && _analysisHeadings.contains(upper.replaceAll(':', ''));
    final isOrderedStep = RegExp(r'^\d+[\).:]').hasMatch(line);
    final isBullet = line.startsWith('- ');

    final style = TextStyle(
      color: textColor,
      fontSize: isAnalysisHeading ? 13.3 : 13.0,
      height: 1.45,
      fontWeight: (isAnalysisHeading || isOrderedStep) ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: isAnalysisHeading ? 0.2 : 0,
    );

    if (isBullet) {
      final bulletText = line.substring(2).trim();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 8, right: 8),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Text(bulletText, style: style)),
        ],
      );
    }

    return Text(line, style: style);
  }

  Widget _buildGeneralAnalysisBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9ED9D3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F8F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  size: 18,
                  color: Color(0xFF0B8A82),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Analisis general de salud',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10363A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xFFE7EEF2),
          ),
          const SizedBox(height: 10),
          _buildPrettyMessageText(
            text,
            textColor: const Color(0xFF1F2937),
            emphasizeSections: true,
          ),
          const SizedBox(height: 10),
          const Text(
            'Orientacion automatizada. No reemplaza la valoracion medica profesional.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 8),
            Text('Pensando una respuesta...', style: TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Escribe tu duda de salud...',
                hintStyle: const TextStyle(fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: const Color(0xFFE5EAF0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5EAF0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0B8A82), width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: const Color(0xFFA8B7C7),
            ),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

enum _ChatMessageKind { chat, generalAnalysis }

class _ChatMessage {
  const _ChatMessage.user(this.text)
      : isUser = true,
        isWarning = false,
        kind = _ChatMessageKind.chat;

  const _ChatMessage.assistant(
    this.text, {
    this.isWarning = false,
    this.kind = _ChatMessageKind.chat,
  }) : isUser = false;

  final String text;
  final bool isUser;
  final bool isWarning;
  final _ChatMessageKind? kind;

  _ChatMessageKind get kindOrDefault => kind ?? _ChatMessageKind.chat;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    final kindRaw = (json['kind'] as String?) ?? 'chat';
    final kind = kindRaw == 'generalAnalysis'
        ? _ChatMessageKind.generalAnalysis
        : _ChatMessageKind.chat;

    return _ChatMessage.assistant(
      (json['text'] as String?) ?? '',
      isWarning: (json['isWarning'] as bool?) ?? false,
      kind: kind,
    )._asRole((json['isUser'] as bool?) ?? false);
  }

  _ChatMessage _asRole(bool user) {
    if (user) {
      return _ChatMessage.user(text);
    }
    return _ChatMessage.assistant(text, isWarning: isWarning, kind: kindOrDefault);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      'isUser': isUser,
      'isWarning': isWarning,
      'kind': kindOrDefault == _ChatMessageKind.generalAnalysis ? 'generalAnalysis' : 'chat',
    };
  }
}
