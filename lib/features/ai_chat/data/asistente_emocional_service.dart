import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../health/data/models/recommendation_context.dart';
import '../../health/data/models/recommendation_result.dart';

class AsistenteEmocionalException implements Exception {
  const AsistenteEmocionalException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

enum AiAssistantStatus {
  available,
  betaUnavailable,
  notConfigured,
  degraded,
}

class AsistenteEmocionalService {
  AsistenteEmocionalService({
    HttpClient? httpClient,
    String? baseUrl,
    Future<String> Function()? idTokenProvider,
    Duration requestTimeout = _requestTimeoutDefault,
    Duration chatHeadersTimeout = _chatHeadersTimeoutDefault,
    Duration chatStreamInactivityTimeout =
        _chatStreamInactivityTimeoutDefault,
  })
    : _httpClient = httpClient ?? HttpClient(),
      _baseUrl = baseUrl ?? _defaultBaseUrl,
      _idTokenProvider = idTokenProvider,
      _requestTimeout = requestTimeout,
      _chatHeadersTimeout = chatHeadersTimeout,
      _chatStreamInactivityTimeout = chatStreamInactivityTimeout {
    debugPrint(
      '[AsistenteEmocionalService] Initialized with baseUrl: "${_baseUrl.isEmpty ? '(EMPTY)' : _baseUrl}"',
    );
    if (_baseUrl.isEmpty && !kReleaseMode) {
      debugPrint(
        '[AsistenteEmocionalService] WARNING: AI_CHAT_BASE_URL is not set. Use --dart-define=AI_CHAT_BASE_URL=... at compile time.',
      );
    }
  }

  static const String _defaultBaseUrl = String.fromEnvironment(
    'AI_CHAT_BASE_URL',
  );
  static const Duration _requestTimeoutDefault = Duration(seconds: 12);
  static const Duration _chatHeadersTimeoutDefault = Duration(seconds: 60);
  static const Duration _chatStreamInactivityTimeoutDefault = Duration(
    seconds: 20,
  );

  /// Verdadero si el build incluyó --dart-define=AI_CHAT_BASE_URL con un valor.
  static bool get isConfigured => _defaultBaseUrl.isNotEmpty;

  /// Realiza un check rápido de disponibilidad con el backend.
  /// No debe tardar más de 8-10 segundos.
  Future<AiAssistantStatus> checkAvailability() async {
    if (!isConfigured) {
      return AiAssistantStatus.notConfigured;
    }

    try {
      final String sanitizedBaseUrl = _baseUrl.endsWith('/')
          ? _baseUrl.substring(0, _baseUrl.length - 1)
          : _baseUrl;
      final Uri endpoint = Uri.parse('$sanitizedBaseUrl/api/ai/health');

      final HttpClientRequest request = await _httpClient
          .getUrl(endpoint)
          .timeout(const Duration(seconds: 8));
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 2),
      );

      if (response.statusCode == HttpStatus.ok) {
        return AiAssistantStatus.available;
      }

      debugPrint(
          '[AsistenteEmocionalService] Availability check returned ${response.statusCode}');
      return AiAssistantStatus.degraded;
    } catch (e) {
      debugPrint('[AsistenteEmocionalService] Availability check failed: $e');
      return AiAssistantStatus.betaUnavailable;
    }
  }

  final HttpClient _httpClient;
  final String _baseUrl;
  final Future<String> Function()? _idTokenProvider;
  final Duration _requestTimeout;
  final Duration _chatHeadersTimeout;
  final Duration _chatStreamInactivityTimeout;

  String get baseUrl => _baseUrl;

  Future<String> _requireIdToken() async {
    if (_idTokenProvider != null) {
      return _idTokenProvider();
    }

    if (_baseUrl.isEmpty) {
      throw const AsistenteEmocionalException(
        'El backend del asistente no esta configurado.',
      );
    }
    if (!_baseUrl.startsWith('https://') && kReleaseMode) {
      throw const AsistenteEmocionalException(
        'La URL del backend debe ser segura (HTTPS) en modo de producción.',
      );
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AsistenteEmocionalException(
        'Necesitas iniciar sesion para usar el asistente. (Usuario no encontrado)',
      );
    }

    final String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AsistenteEmocionalException(
        'No se pudo validar la sesion del usuario.',
      );
    }

    return idToken;
  }

  Stream<String> streamReply(
    String message, {
    String? requestDebugId,
  }) async* {
    final String idToken = await _requireIdToken();
    final Stopwatch stopwatch = Stopwatch()..start();
    bool hasReceivedFirstChunk = false;
    bool hasReceivedAnyChunk = false;
    int rawChunkCount = 0;
    int usefulChunkCount = 0;
    int totalChars = 0;
    final String debugId = requestDebugId ?? 'chat';

    // Sanitize baseUrl to avoid double slashes
    final String sanitizedBaseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;

    final Uri endpoint = Uri.parse('$sanitizedBaseUrl/api/ai/chat');
    debugPrint(
      '[AsistenteEmocionalService][$debugId] Chat request started: endpoint=$endpoint messageLength=${message.length}',
    );

    try {
      final HttpClientRequest request = await _httpClient
          .postUrl(endpoint)
          .timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'text/plain');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.add(
        utf8.encode(jsonEncode(<String, String>{'message': message})),
      );

      final HttpClientResponse response = await request.close().timeout(
        _chatHeadersTimeout,
      );
      debugPrint(
        '[AsistenteEmocionalService][$debugId] Chat headers received: status=${response.statusCode} elapsedMs=${stopwatch.elapsedMilliseconds}',
      );

      final Stream<String> decodedStream = response.transform(utf8.decoder);

      if (response.statusCode != HttpStatus.ok) {
        final String errorBody = (await decodedStream.join()).trim();
        debugPrint(
          '[AsistenteEmocionalService][$debugId] Chat error body: $errorBody',
        );
        throw AsistenteEmocionalException(
          errorBody.isNotEmpty
              ? errorBody
              : 'No se pudo obtener una respuesta del asistente.',
          statusCode: response.statusCode,
        );
      }

      final Stream<String> meaningfulStream = decodedStream
          .map((chunk) {
            rawChunkCount += 1;
            debugPrint(
              '[AsistenteEmocionalService][$debugId] Raw chunk received: rawChunkCount=$rawChunkCount rawLength=${chunk.length}',
            );
            return chunk;
          })
          .where((chunk) {
            final bool isMeaningful = _isMeaningfulChatChunk(chunk);
            if (!isMeaningful) {
              debugPrint(
                '[AsistenteEmocionalService][$debugId] Ignored non-meaningful chunk: rawChunkCount=$rawChunkCount rawLength=${chunk.length}',
              );
            }
            return isMeaningful;
          });

      await for (final String chunk in meaningfulStream.timeout(
        _chatStreamInactivityTimeout,
        onTimeout: (EventSink<String> sink) {
          debugPrint(
            '[AsistenteEmocionalService][$debugId] Chat stream inactivity timeout triggered: elapsedMs=${stopwatch.elapsedMilliseconds} rawChunkCount=$rawChunkCount usefulChunkCount=$usefulChunkCount',
          );
          sink.addError(
            const AsistenteEmocionalException(
              'El asistente tardó demasiado en completar la respuesta. Intenta de nuevo.',
            ),
          );
          sink.close();
        },
      )) {
        usefulChunkCount += 1;
        hasReceivedAnyChunk = true;
        totalChars += chunk.length;
        if (!hasReceivedFirstChunk) {
          hasReceivedFirstChunk = true;
          debugPrint(
            '[AsistenteEmocionalService][$debugId] First useful chat chunk received: elapsedMs=${stopwatch.elapsedMilliseconds} usefulChunkCount=$usefulChunkCount chunkLength=${chunk.length}',
          );
        }
        debugPrint(
          '[AsistenteEmocionalService][$debugId] Useful chat chunk forwarded: usefulChunkCount=$usefulChunkCount totalChars=$totalChars',
        );
        yield chunk;
      }
      if (!hasReceivedAnyChunk) {
        debugPrint(
          '[AsistenteEmocionalService][$debugId] Chat stream ended without useful content: rawChunkCount=$rawChunkCount usefulChunkCount=$usefulChunkCount',
        );
        throw const AsistenteEmocionalException(
          'El asistente no devolvió contenido. Intenta de nuevo.',
        );
      }

      debugPrint(
        '[AsistenteEmocionalService][$debugId] Chat stream completed: elapsedMs=${stopwatch.elapsedMilliseconds} rawChunkCount=$rawChunkCount usefulChunkCount=$usefulChunkCount receivedAnyChunk=$hasReceivedAnyChunk totalChars=$totalChars',
      );
    } on TimeoutException catch (error) {
      debugPrint(
        '[AsistenteEmocionalService][$debugId] Chat stream timeout: elapsedMs=${stopwatch.elapsedMilliseconds} rawChunkCount=$rawChunkCount usefulChunkCount=$usefulChunkCount receivedFirstChunk=$hasReceivedFirstChunk error=$error',
      );
      throw const AsistenteEmocionalException(
        'El asistente tardó demasiado en responder. Intenta de nuevo.',
      );
    } on SocketException catch (error) {
      debugPrint(
        '[AsistenteEmocionalService][$debugId] Chat socket failure: elapsedMs=${stopwatch.elapsedMilliseconds} rawChunkCount=$rawChunkCount usefulChunkCount=$usefulChunkCount receivedFirstChunk=$hasReceivedFirstChunk error=$error',
      );
      throw const AsistenteEmocionalException(
        'No se pudo conectar con el asistente en este momento.',
      );
    } catch (e) {
      debugPrint(
        '[AsistenteEmocionalService][$debugId] Chat stream failed: elapsedMs=${stopwatch.elapsedMilliseconds} rawChunkCount=$rawChunkCount usefulChunkCount=$usefulChunkCount receivedFirstChunk=$hasReceivedFirstChunk error=$e',
      );
      if (e is TimeoutException) {
        throw const AsistenteEmocionalException(
          'El asistente tardó demasiado en responder. Intenta de nuevo.',
        );
      }
      rethrow;
    }
  }

  Future<RecommendationResult> fetchRecommendation(
    RecommendationContext context,
  ) async {
    final String idToken = await _requireIdToken();
    final String sanitizedBaseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final Uri endpoint = Uri.parse('$sanitizedBaseUrl/api/ai/recommendation');
    debugPrint('[AsistenteEmocionalService] Request URL: $endpoint');

    try {
      final HttpClientRequest request = await _httpClient
          .postUrl(endpoint)
          .timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.add(
        utf8.encode(jsonEncode(<String, dynamic>{'context': context.toJson()})),
      );

      final HttpClientResponse response = await request.close().timeout(
        _requestTimeout,
      );
      debugPrint(
        '[AsistenteEmocionalService] Response Status: ${response.statusCode}',
      );

      final String responseBody =
          (await response
                  .transform(utf8.decoder)
                  .join()
                  .timeout(_requestTimeout))
              .trim();

      if (response.statusCode != HttpStatus.ok) {
        debugPrint('[AsistenteEmocionalService] Error body: $responseBody');
        throw AsistenteEmocionalException(
          responseBody.isNotEmpty
              ? responseBody
              : 'No se pudo obtener una recomendacion inteligente.',
          statusCode: response.statusCode,
        );
      }

      try {
        final Object? decoded = jsonDecode(responseBody);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Respuesta JSON invalida.');
        }
        return RecommendationResult.fromJson(decoded);
      } catch (error) {
        debugPrint('[AsistenteEmocionalService] JSON Decode Error: $error');
        throw AsistenteEmocionalException(
          'La recomendacion estructurada no se pudo interpretar: $error',
        );
      }
    } catch (e) {
      debugPrint('[AsistenteEmocionalService] Recommendation Exception: $e');
      rethrow;
    }
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}

bool _isMeaningfulChatChunk(String chunk) {
  final String trimmed = chunk.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  if (RegExp(r'^\[RECOMMEND:.*?\]$').hasMatch(trimmed)) {
    return true;
  }

  return true;
}
