import 'dart:convert';
import 'dart:io';

class GeminiHealthService {
  GeminiHealthService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  static const List<String> _fallbackModels = <String>[
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
  ];
  static const int _maxOutputTokens = 1200;

  static String get _apiKey {
    const directKey = String.fromEnvironment('GEMINI_API_KEY');
    if (directKey.trim().isNotEmpty) return directKey;

    // Compatibilidad para equipos que ya usan un prefijo NEXT_PUBLIC_ en defines.
    const prefixedKey = String.fromEnvironment('NEXT_PUBLIC_GEMINI_API_KEY');
    return prefixedKey;
  }

  Future<String> generateHealthReply({
    required String patientName,
    required String clinicalContext,
    required String userMessage,
    List<String> recentTurns = const <String>[],
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw const GeminiConfigException(
        'Falta la API key de Gemini. Configura GEMINI_API_KEY en .vscode/dart_defines.local.json o inicia con --dart-define=GEMINI_API_KEY=TU_CLAVE',
      );
    }

    final prompt = _buildPrompt(
      patientName: patientName,
      clinicalContext: clinicalContext,
      userMessage: userMessage,
      recentTurns: recentTurns,
    );

    _GeminiHttpException? lastHttpError;

    for (final model in _candidateModels()) {
      try {
        final firstReply = await _generateWithRetry(model: model, prompt: prompt);
        var finalText = firstReply.text;

        if (firstReply.finishReason == 'MAX_TOKENS') {
          final continuedText = await _continueTruncatedAnswer(
            model: model,
            originalPrompt: prompt,
            partialAnswer: finalText,
          );
          if (continuedText.trim().isNotEmpty) {
            finalText = '$finalText\n$continuedText'.trim();
          }
        }

        return _normalizeAnswer(finalText);
      } on _GeminiHttpException catch (error) {
        lastHttpError = error;
        // Si el modelo no existe o esta saturado temporalmente, probamos el siguiente.
        if (error.statusCode == 404 || _isRetryableStatus(error.statusCode)) {
          continue;
        }
        throw GeminiRequestException(
          'Error de Gemini (${error.statusCode}) con modelo ${error.model}: ${error.rawBody}',
        );
      }
    }

    if (lastHttpError != null) {
      throw GeminiRequestException(
        'No hay modelos Gemini disponibles para esta API key. '
        'Ultimo error (${lastHttpError.statusCode}) en ${lastHttpError.model}: ${lastHttpError.rawBody}',
      );
    }

    throw const GeminiRequestException(
      'No se encontro un modelo Gemini candidato para generar contenido.',
    );
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 429 || statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504;
  }

  Future<_ModelReply> _generateWithRetry({
    required String model,
    required String prompt,
  }) async {
    const delays = <Duration>[
      Duration(milliseconds: 350),
      Duration(milliseconds: 900),
    ];

    for (var attempt = 0; ; attempt++) {
      try {
        return await _generateWithModel(model: model, prompt: prompt);
      } on _GeminiHttpException catch (error) {
        final hasMoreRetries = attempt < delays.length;
        if (!_isRetryableStatus(error.statusCode) || !hasMoreRetries) {
          rethrow;
        }
        await Future.delayed(delays[attempt]);
      }
    }
  }

  Iterable<String> _candidateModels() {
    const directModel = String.fromEnvironment('GEMINI_MODEL');
    const prefixedModel = String.fromEnvironment('NEXT_PUBLIC_GEMINI_MODEL');

    final ordered = <String>[];
    if (directModel.trim().isNotEmpty) ordered.add(directModel.trim());
    if (prefixedModel.trim().isNotEmpty) ordered.add(prefixedModel.trim());
    ordered.addAll(_fallbackModels);

    // Unicos, conservando orden.
    return ordered.toSet();
  }

  Future<String> _continueTruncatedAnswer({
    required String model,
    required String originalPrompt,
    required String partialAnswer,
  }) async {
    var accumulated = '';
    var currentPartial = partialAnswer;

    // Hasta 2 continuaciones para evitar respuestas interminables.
    for (var attempt = 0; attempt < 2; attempt++) {
      final continuationPrompt = '''
Completa la respuesta anterior porque quedo truncada por limite de tokens.
No repitas contenido ya escrito.
Mantente en espanol y cierra ideas completas.

Pregunta original del paciente:
$originalPrompt

Respuesta parcial generada hasta ahora:
$currentPartial

Entrega solo la continuacion faltante.
''';

      final continuation = await _generateWithModel(
        model: model,
        prompt: continuationPrompt,
      );

      if (continuation.text.trim().isEmpty) {
        break;
      }

      accumulated = accumulated.isEmpty
          ? continuation.text.trim()
          : '$accumulated\n${continuation.text.trim()}';
      currentPartial = '$currentPartial\n${continuation.text}'.trim();

      if (continuation.finishReason != 'MAX_TOKENS') {
        break;
      }
    }

    return accumulated;
  }

  _ModelReply _parseModelReply(Map<String, dynamic> decoded) {
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const GeminiRequestException(
        'Gemini no devolvio candidatos en la respuesta.',
      );
    }

    final candidate = candidates.first as Map<String, dynamic>;
    final finishReason = (candidate['finishReason'] as String?)?.trim();
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw const GeminiRequestException(
        'Gemini devolvio una respuesta sin texto.',
      );
    }

    final text = parts
        .whereType<Map<String, dynamic>>()
        .map((part) => (part['text'] as String?)?.trim() ?? '')
        .where((chunk) => chunk.isNotEmpty)
        .join('\n')
        .trim();

    if (text.isEmpty) {
      throw const GeminiRequestException(
        'Gemini devolvio texto vacio.',
      );
    }

    return _ModelReply(
      text: text,
      finishReason: finishReason ?? 'UNKNOWN',
    );
  }

  String _normalizeAnswer(String text) {
    final cleanedLines = text
        .replaceAll('**', '')
        .replaceAll(RegExp(r'\((\d+)\)\s*'), '') // Ej: "(29)"
        .replaceAll(RegExp(r'\b([1-9]\d)\)\s*'), '') // Ej: "28)"
        .split('\n')
        .map((line) => line.trim())
        .where((line) {
          if (line.isEmpty) return false;

          final lower = line.toLowerCase();
          // Filtra texto de control/artefactos que a veces anteceden la respuesta.
          if (lower.contains('contact doctor/er?')) return false;
          if (lower.contains('no definitive diagnosis?')) return false;
          if (lower.contains('no invented data?')) return false;
          if (lower.startsWith('actionable, simple steps:')) return false;
          return true;
        })
        .toList();

    return cleanedLines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Future<_ModelReply> _generateWithModel({
    required String model,
    required String prompt,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
    );

    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(<String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': prompt},
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.65,
        'topP': 0.9,
        'maxOutputTokens': _maxOutputTokens,
      },
    }));

    final response = await request.close();
    final raw = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _GeminiHttpException(
        statusCode: response.statusCode,
        rawBody: raw,
        model: model,
      );
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return _parseModelReply(decoded);
  }

  String _buildPrompt({
    required String patientName,
    required String clinicalContext,
    required String userMessage,
    required List<String> recentTurns,
  }) {
    final historyText = recentTurns.isEmpty
        ? 'Sin historial previo.'
        : recentTurns.map((line) => '- $line').join('\n');

    return '''
Eres un asistente de salud clinica para pacientes cronicos en una app movil.
Habla en espanol, tono humano, empatico y claro.

Reglas de estilo:
- Explica con lenguaje sencillo y practico.
- Da pasos accionables cortos.
- Si detectas alerta potencial, sugiere contactar al medico o urgencias segun gravedad.
- No des diagnosticos definitivos.
- No inventes datos no presentes.

Paciente: $patientName
Contexto clinico disponible:
$clinicalContext

Historial reciente del chat:
$historyText

Pregunta del paciente:
$userMessage

Responde en 3 bloques:
1) Resumen breve de lo que entendiste.
2) Explicacion orientativa personalizada.
3) Siguiente accion recomendada hoy.

Formato obligatorio:
- Escribe en texto plano, sin markdown (sin asteriscos ni encabezados con #).
- Mantente entre 120 y 220 palabras.
- Cierra cada bloque con una idea completa.
- No incluyas texto de control, checklist interno ni frases como "contact doctor/ER?", "No definitive diagnosis?" o "No invented data?".
- No agregues numeracion de depuracion por palabra o token (ejemplo: "(29)", "28)").
''';
  }
}

class _ModelReply {
  const _ModelReply({
    required this.text,
    required this.finishReason,
  });

  final String text;
  final String finishReason;
}

class GeminiConfigException implements Exception {
  const GeminiConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeminiRequestException implements Exception {
  const GeminiRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _GeminiHttpException implements Exception {
  const _GeminiHttpException({
    required this.statusCode,
    required this.rawBody,
    required this.model,
  });

  final int statusCode;
  final String rawBody;
  final String model;
}
