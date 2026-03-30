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

class AsistenteEmocionalService {
  AsistenteEmocionalService({HttpClient? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? HttpClient(),
      _baseUrl = baseUrl ?? _defaultBaseUrl {
    print('[AsistenteEmocionalService] Initialized with baseUrl: "${_baseUrl.isEmpty ? '(EMPTY)' : _baseUrl}"');
    if (_baseUrl.isEmpty && !kReleaseMode) {
      print('[AsistenteEmocionalService] WARNING: AI_CHAT_BASE_URL is not set. Use --dart-define=AI_CHAT_BASE_URL=... at compile time.');
    }
  }

  static const String _defaultBaseUrl = String.fromEnvironment(
    'AI_CHAT_BASE_URL',
  );

  /// Verdadero si el build incluyó --dart-define=AI_CHAT_BASE_URL con un valor.
  static bool get isConfigured => _defaultBaseUrl.isNotEmpty;

  final HttpClient _httpClient;
  final String _baseUrl;

  String get baseUrl => _baseUrl;

  Future<String> _requireIdToken() async {
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

  Stream<String> streamReply(String message) async* {
    final String idToken = await _requireIdToken();
    
    // Sanitize baseUrl to avoid double slashes
    final String sanitizedBaseUrl = _baseUrl.endsWith('/') 
        ? _baseUrl.substring(0, _baseUrl.length - 1) 
        : _baseUrl;
        
    final Uri endpoint = Uri.parse('$sanitizedBaseUrl/api/ai/chat');
    print('[AsistenteEmocionalService] Request URL: $endpoint');

    try {
      final HttpClientRequest request = await _httpClient.postUrl(endpoint).timeout(
        const Duration(seconds: 30),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'text/plain');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.add(utf8.encode(jsonEncode(<String, String>{'message': message})));

      final HttpClientResponse response = await request.close();
      print('[AsistenteEmocionalService] Response Status: ${response.statusCode}');

      final Stream<String> decodedStream = response.transform(utf8.decoder);

      if (response.statusCode != HttpStatus.ok) {
        final String errorBody = (await decodedStream.join()).trim();
        print('[AsistenteEmocionalService] Error body: $errorBody');
        throw AsistenteEmocionalException(
          errorBody.isNotEmpty
              ? errorBody
              : 'No se pudo obtener una respuesta del asistente.',
          statusCode: response.statusCode,
        );
      }

      await for (final String chunk in decodedStream) {
        if (chunk.isNotEmpty) {
          yield chunk;
        }
      }
    } catch (e) {
      print('[AsistenteEmocionalService] Stream Exception: $e');
      rethrow;
    }
  }

  Future<RecommendationResult> fetchRecommendation(
    RecommendationContext context,
  ) async {
    final String idToken = await _requireIdToken();
    final Uri endpoint = Uri.parse('$_baseUrl/api/ai/recommendation');
    print('[AsistenteEmocionalService] Request URL: $endpoint');

    try {
      final HttpClientRequest request = await _httpClient.postUrl(endpoint);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.add(
        utf8.encode(jsonEncode(<String, dynamic>{'context': context.toJson()})),
      );

      final HttpClientResponse response = await request.close();
      print('[AsistenteEmocionalService] Response Status: ${response.statusCode}');

      final String responseBody = (await response.transform(utf8.decoder).join())
          .trim();

      if (response.statusCode != HttpStatus.ok) {
        print('[AsistenteEmocionalService] Error body: $responseBody');
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
        print('[AsistenteEmocionalService] JSON Decode Error: $error');
        throw AsistenteEmocionalException(
          'La recomendacion estructurada no se pudo interpretar: $error',
        );
      }
    } catch (e) {
      print('[AsistenteEmocionalService] Recommendation Exception: $e');
      rethrow;
    }
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}
