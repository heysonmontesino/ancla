import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../core/legal/legal_strings.dart';
import '../../../core/ui/widgets/pill_toast.dart';
import '../../sessions/data/firestore_audio_repository.dart';
import '../../sessions/models/audio_session.dart';
import '../../sessions/ui/session_player_screen.dart';
import '../data/asistente_emocional_service.dart';
import 'chat_response_formatter.dart';

const Color _aiChatBackground = Color(0xFF05070A);
const Color _aiChatForeground = Color(0xFFEDF2F7);
const Color _aiChatPrimary = Color(0xFF7F9CF5);
const Color _aiChatCard = Color(0xFF0B0E17);
const Color _aiChatSecondary = Color(0xFF111524);
const Color _aiChatMuted = Color(0xFF718096);
const String _aiChatConsentAcceptedKey = PrefsKeys.aiChatConsentAccepted;

class AsistenteEmocionalScreen extends StatefulWidget {
  const AsistenteEmocionalScreen({
    super.key,
    AsistenteEmocionalService? service,
    Future<List<AudioSession>> Function()? sessionsLoader,
    SpeechToText? speechToText,
    AiAssistantStatus? initialStatus,
  }) : _service = service,
       _sessionsLoader = sessionsLoader,
       _speechToText = speechToText,
       _initialStatus = initialStatus;

  final AsistenteEmocionalService? _service;
  final Future<List<AudioSession>> Function()? _sessionsLoader;
  final SpeechToText? _speechToText;
  final AiAssistantStatus? _initialStatus;

  @override
  State<AsistenteEmocionalScreen> createState() =>
      _AsistenteEmocionalScreenState();
}

class _AsistenteEmocionalScreenState extends State<AsistenteEmocionalScreen> {
  late final AsistenteEmocionalService _service;
  late final bool _ownsService;
  late final SpeechToText _speechToText;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<String>? _replySubscription;
  String _responseText = '';
  String _submittedMessage = '';
  String? _errorText;
  bool _isSending = false;
  bool _hasShownConsentDialog = false;
  bool _isCheckingConnection = false;
  String? _connectionStatus;
  late AiAssistantStatus _currentStatus;
  bool _backendWarmedUp = false;
  bool _isWarmingUp = false;
  int _activeRequestId = 0;
  bool _speechReady = false;
  bool _isPreparingSpeech = false;
  bool _isListening = false;
  String? _speechLocaleId;
  String? _speechStatusText;
  String _dictationBaseText = '';

  List<AudioSession> _availableSessions = [];

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? AsistenteEmocionalService();
    _ownsService = widget._service == null;
    _speechToText = widget._speechToText ?? SpeechToText();

    // Use initial status if provided, or fallback to checking configured state
    _currentStatus =
        widget._initialStatus ??
        (AsistenteEmocionalService.isConfigured
            ? AiAssistantStatus.available
            : AiAssistantStatus.notConfigured);

    if (_currentStatus == AiAssistantStatus.available) {
      unawaited(_checkAiConsent());
      unawaited(_loadSessions());
    }

    // Re-verify if not provided or if we want latest state
    if (widget._initialStatus == null) {
      unawaited(_verifyStatus());
    }
  }

  Future<void> _verifyStatus() async {
    final status = await _service.checkAvailability();
    if (mounted) {
      setState(() {
        _currentStatus = status;
      });
    }
  }

  @override
  void dispose() {
    _replySubscription?.cancel();
    if (_isListening) {
      unawaited(_speechToText.cancel());
    }
    _messageController.dispose();
    _scrollController.dispose();
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final sessions =
          await (widget._sessionsLoader ?? FirestoreAudioRepository.fetchSessions)();
      if (mounted) {
        setState(() => _availableSessions = sessions);
      }
    } catch (error) {
      debugPrint('[AsistenteEmocionalScreen] Session preload failed: $error');
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isCheckingConnection = true;
      _connectionStatus = null;
    });

    try {
      final String baseUrl = _service.baseUrl;
      final HttpClient client = HttpClient();
      final Uri uri = Uri.parse('$baseUrl/health');
      final HttpClientRequest request = await client.getUrl(uri).timeout(
            const Duration(seconds: 5),
          );
      final HttpClientResponse response = await request.close();
      if (response.statusCode == 200) {
        setState(() => _connectionStatus = 'Conexión exitosa a $baseUrl');
      } else {
        setState(() => _connectionStatus = 'Error ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _connectionStatus = 'Fallo: ${e.toString()}');
    } finally {
      setState(() => _isCheckingConnection = false);
    }
  }

  Future<void> _sendMessage() async {
    if (!_backendWarmedUp) {
      final bool ready = await _wakeUpBackend();
      if (!ready) {
        setState(() {
          _errorText =
              'No se pudo conectar con el asistente. '
              'Verifica tu conexión e intenta de nuevo.';
        });
        return;
      }
    }

    final String message = _messageController.text.trim();
    if (message.isEmpty || _isSending) {
      return;
    }

    if (_isListening) {
      await _stopListening();
    }

    await _replySubscription?.cancel();
    final int requestId = ++_activeRequestId;
    int chunkCount = 0;

    debugPrint(
      '[AsistenteEmocionalScreen][$requestId] start send: messageLength=${message.length} previousIsSending=$_isSending',
    );

    setState(() {
      _submittedMessage = message;
      _responseText = '';
      _errorText = null;
      _isSending = true;
      _speechStatusText = null;
    });
    debugPrint(
      '[AsistenteEmocionalScreen][$requestId] _isSending=true committed',
    );
    _messageController.clear();

    _replySubscription = _service
        .streamReply(message, requestDebugId: 'request-$requestId')
        .listen(
      (chunk) {
        if (!mounted || requestId != _activeRequestId) {
          debugPrint(
            '[AsistenteEmocionalScreen][$requestId] chunk ignored: mounted=$mounted activeRequestId=$_activeRequestId',
          );
          return;
        }
        chunkCount += 1;
        debugPrint(
          '[AsistenteEmocionalScreen][$requestId] chunk received: chunkCount=$chunkCount chunkLength=${chunk.length} trimmedLength=${chunk.trim().length}',
        );
        setState(() {
          _responseText += chunk;
        });
        _scrollToBottom();
      },
      onError: (Object error) {
        if (!mounted || requestId != _activeRequestId) {
          debugPrint(
            '[AsistenteEmocionalScreen][$requestId] stream error ignored: mounted=$mounted activeRequestId=$_activeRequestId error=$error',
          );
          return;
        }
        debugPrint(
          '[AsistenteEmocionalScreen][$requestId] stream error: chunkCount=$chunkCount error=$error',
        );
        setState(() {
          _errorText = error is AsistenteEmocionalException
              ? error.message
              : 'No se pudo conectar con el asistente en este momento.';
          _isSending = false;
        });
        debugPrint(
          '[AsistenteEmocionalScreen][$requestId] _isSending=false committed via onError',
        );
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted || requestId != _activeRequestId) {
          debugPrint(
            '[AsistenteEmocionalScreen][$requestId] stream done ignored: mounted=$mounted activeRequestId=$_activeRequestId chunkCount=$chunkCount',
          );
          return;
        }
        final ChatResponseViewData formattedResponse =
            formatChatResponseForDisplay(_responseText);
        final bool rejectedForLanguage = shouldRejectUnexpectedEnglishResponse(
          userMessage: _submittedMessage,
          responseText: formattedResponse.text,
        );
        debugPrint(
          '[AsistenteEmocionalScreen][$requestId] stream done: chunkCount=$chunkCount responseTrimmedLength=${_responseText.trim().length} hasError=${_errorText != null} rejectedForLanguage=$rejectedForLanguage',
        );
        setState(() {
          _isSending = false;
          if (rejectedForLanguage) {
            _responseText = '';
            _errorText =
                'El asistente no devolvió una respuesta válida en español. Intenta de nuevo.';
          } else if (_responseText.trim().isEmpty && _errorText == null) {
            _errorText =
                'El asistente no devolvió contenido. Intenta de nuevo.';
          }
        });
        debugPrint(
          '[AsistenteEmocionalScreen][$requestId] _isSending=false committed via onDone finalError=$_errorText',
        );
        _scrollToBottom();
      },
      cancelOnError: true,
    );
  }

  Future<bool> _wakeUpBackend() async {
    if (_backendWarmedUp) return true;

    setState(() {
      _isWarmingUp = true;
      _errorText = null;
    });

    try {
      final status = await _service.checkAvailability();
      if (status == AiAssistantStatus.available) {
        if (mounted) {
          setState(() {
            _backendWarmedUp = true;
            _isWarmingUp = false;
          });
        }
        return true;
      }

      if (mounted) {
        setState(() => _isWarmingUp = false);
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() => _isWarmingUp = false);
      }
      return false;
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isSending || _isPreparingSpeech) {
      return;
    }

    if (_isListening) {
      await _stopListening();
      return;
    }

    await _startListening();
  }

  Future<void> _startListening() async {
    setState(() {
      _isPreparingSpeech = true;
      _speechStatusText = 'Activando micrófono...';
    });

    final bool speechReady = await _ensureSpeechReady();
    if (!mounted) {
      return;
    }

    if (!speechReady) {
      setState(() {
        _isPreparingSpeech = false;
        _speechStatusText = null;
      });
      _showVoiceFeedback(
        'No pudimos activar el dictado por voz en este dispositivo.',
      );
      return;
    }

    _dictationBaseText = _messageController.text.trim();

    try {
      await _speechToText.listen(
        onResult: _handleSpeechResult,
        localeId: _speechLocaleId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isPreparingSpeech = false;
        _isListening = _speechToText.isListening;
        _speechStatusText = _isListening
            ? 'Escuchando... puedes detener o cancelar.'
            : 'Dictado listo. Puedes editarlo o enviarlo.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreparingSpeech = false;
        _isListening = false;
        _speechStatusText = null;
      });
      _showVoiceFeedback(
        'No se pudo iniciar el dictado por voz. Intenta de nuevo.',
      );
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = false;
      _isPreparingSpeech = false;
      _speechStatusText = _messageController.text.trim().isEmpty
          ? null
          : 'Dictado listo. Puedes editarlo o enviarlo.';
    });
  }

  Future<void> _cancelListening() async {
    await _speechToText.cancel();
    if (!mounted) {
      return;
    }

    _replaceMessageText(_dictationBaseText);
    setState(() {
      _isListening = false;
      _isPreparingSpeech = false;
      _speechStatusText = null;
    });
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechReady) {
      return true;
    }

    try {
      final bool available = await _speechToText.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );

      if (!available) {
        return false;
      }

      final List<LocaleName> locales = await _speechToText.locales();
      _speechLocaleId = _pickPreferredSpeechLocale(locales);
      _speechReady = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _pickPreferredSpeechLocale(List<LocaleName> locales) {
    for (final locale in locales) {
      if (locale.localeId == 'es_CO') {
        return locale.localeId;
      }
    }

    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('es')) {
        return locale.localeId;
      }
    }

    return null;
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }

    final String transcribedText = result.recognizedWords.trim();
    final String mergedText = _mergeDictationText(
      _dictationBaseText,
      transcribedText,
    );
    _replaceMessageText(mergedText);

    setState(() {
      _speechStatusText = result.finalResult
          ? 'Dictado listo. Puedes editarlo o enviarlo.'
          : 'Escuchando... puedes detener o cancelar.';
    });
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    final bool listening = status == 'listening';
    final bool finished = status == 'done' || status == 'notListening';

    if (listening) {
      setState(() {
        _isListening = true;
        _isPreparingSpeech = false;
        _speechStatusText = 'Escuchando... puedes detener o cancelar.';
      });
      return;
    }

    if (finished) {
      setState(() {
        _isListening = false;
        _isPreparingSpeech = false;
        _speechStatusText = _messageController.text.trim().isEmpty
            ? null
            : 'Dictado listo. Puedes editarlo o enviarlo.';
      });
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = false;
      _isPreparingSpeech = false;
      _speechStatusText = null;
    });

    _showVoiceFeedback(_speechErrorMessage(error));
  }

  String _mergeDictationText(String baseText, String transcribedText) {
    final String cleanBase = baseText.trim();
    final String cleanTranscribed = transcribedText.trim();

    if (cleanTranscribed.isEmpty) {
      return cleanBase;
    }
    if (cleanBase.isEmpty) {
      return cleanTranscribed;
    }

    return '$cleanBase $cleanTranscribed';
  }

  void _replaceMessageText(String text) {
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _speechErrorMessage(SpeechRecognitionError error) {
    final String normalized = error.errorMsg.toLowerCase();

    if (
        normalized.contains('permission') ||
        normalized.contains('not authorized') ||
        normalized.contains('denied')) {
      return 'Necesitas permitir el micrófono para usar el dictado por voz.';
    }

    if (normalized.contains('unavailable')) {
      return 'El dictado por voz no está disponible en este dispositivo.';
    }

    return 'No se pudo transcribir tu voz en este momento. Intenta de nuevo.';
  }

  void _showVoiceFeedback(String message) {
    PillToast.show(context, message, isError: true);
  }

  Future<void> _checkAiConsent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool accepted = prefs.getBool(_aiChatConsentAcceptedKey) ?? false;

    if (!mounted || accepted || _hasShownConsentDialog) {
      return;
    }

    _hasShownConsentDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_showConsentDialog());
    });
  }

  Future<void> _showConsentDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: _aiChatCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            LegalStrings.aiConsentModalTitle,
            style: GoogleFonts.plusJakartaSans(
              color: _aiChatForeground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          content: Text(
            LegalStrings.aiConsentModalBody,
            style: GoogleFonts.plusJakartaSans(
              color: _aiChatMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).maybePop();
              },
              style: TextButton.styleFrom(
                foregroundColor: _aiChatMuted,
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(LegalStrings.aiConsentModalSecondaryButton),
            ),
            FilledButton(
              onPressed: () async {
                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                await prefs.setBool(_aiChatConsentAcceptedKey, true);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: _aiChatPrimary,
                foregroundColor: _aiChatBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              child: Text(LegalStrings.aiConsentModalPrimaryButton),
            ),
          ],
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _aiChatBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _aiChatForeground),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Regresar',
        ),
        actions: [
          IconButton(
            onPressed: _isCheckingConnection ? null : _testConnection,
            icon: _isCheckingConnection
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _aiChatForeground,
                    ),
                  )
                : const Icon(Icons.network_check_rounded, color: _aiChatForeground),
            tooltip: 'Probar conexión',
          ),
        ],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Chat de apoyo emocional',
                style: GoogleFonts.plusJakartaSans(
                  color: _aiChatForeground,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _aiChatPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _aiChatPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'BETA',
                style: GoogleFonts.plusJakartaSans(
                  color: _aiChatPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child:
            (_currentStatus == AiAssistantStatus.available)
                ? _buildChat()
                : _buildUnavailable(),
      ),
    );
  }

  Widget _buildUnavailable() {
    String title = 'Asistente en mantenimiento';
    String description =
        'Estamos terminando esta experiencia para que sea útil y segura. Por ahora el asistente no está disponible.';
    IconData icon = Icons.construction_rounded;

    if (_currentStatus == AiAssistantStatus.notConfigured) {
      title = 'Asistente en activación';
      description =
          'Esta función se activará gradualmente en tu región. Estamos trabajando para traértela pronto.';
      icon = Icons.upcoming_rounded;
    } else if (_currentStatus == AiAssistantStatus.degraded) {
      title = 'Asistente saturado';
      description =
          'Estamos recibiendo muchas consultas en este momento. Por favor, intenta de nuevo en unos minutos o usa las alternativas.';
      icon = Icons.hourglass_empty_rounded;
    } else if (_currentStatus == AiAssistantStatus.betaUnavailable) {
      title = 'Beta en pausa';
      description =
          'La versión beta del asistente está temporalmente cerrada por mantenimiento programado o actualizaciones.';
      icon = Icons.pause_circle_outline_rounded;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _aiChatPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _aiChatPrimary, size: 40),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: _aiChatForeground,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: GoogleFonts.plusJakartaSans(
            color: _aiChatMuted,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Entendido, regresar'),
          style: FilledButton.styleFrom(
            backgroundColor: _aiChatPrimary,
            foregroundColor: _aiChatBackground,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        if (_currentStatus == AiAssistantStatus.degraded) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isCheckingConnection ? null : _testConnection,
            icon:
                _isCheckingConnection
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _aiChatForeground,
                      ),
                    )
                    : const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar conexión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _aiChatForeground,
              side: BorderSide(color: _aiChatForeground.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              const _CompactLegalNotice(),
              if (_connectionStatus != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _connectionStatus!.startsWith('Conexión')
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _connectionStatus!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: _connectionStatus!.startsWith('Conexión')
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_submittedMessage.isNotEmpty) ...[
                _BubbleCard(
                  label: 'TU MENSAJE',
                  text: _submittedMessage,
                  backgroundColor: _aiChatSecondary.withValues(alpha: 0.58),
                ),
                const SizedBox(height: 12),
              ],
              _BubbleCard(
                label: 'RESPUESTA',
                text: _errorText ?? _responseText,
                backgroundColor: _aiChatCard,
                placeholder: _isSending
                    ? 'Escribiendo...'
                    : 'Envía un mensaje corto para comenzar.',
                isError: _errorText != null,
                sessions: _availableSessions,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: _aiChatBackground,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.plusJakartaSans(
                  color: _aiChatForeground,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje breve...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: _aiChatMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: _aiChatCard,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: IconButton(
                    onPressed: (_isSending || _isPreparingSpeech)
                        ? null
                        : _toggleVoiceInput,
                    tooltip: _isListening ? 'Detener dictado' : 'Dictar mensaje',
                    icon: _isPreparingSpeech
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _aiChatPrimary,
                            ),
                          )
                        : Icon(
                            _isListening
                                ? Icons.stop_circle_outlined
                                : Icons.mic_none_rounded,
                            color: _isListening ? _aiChatPrimary : _aiChatMuted,
                          ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: _aiChatPrimary),
                  ),
                ),
              ),
              if (_speechStatusText != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _isListening
                          ? Icons.graphic_eq_rounded
                          : Icons.check_circle_outline_rounded,
                      color: _aiChatPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _speechStatusText!,
                        style: GoogleFonts.plusJakartaSans(
                          color: _aiChatMuted.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_isListening)
                      TextButton(
                        onPressed: _cancelListening,
                        style: TextButton.styleFrom(
                          foregroundColor: _aiChatPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_isSending || _isWarmingUp) ? null : _sendMessage,
                  style: FilledButton.styleFrom(
                    backgroundColor: _aiChatPrimary,
                    foregroundColor: _aiChatBackground,
                    disabledBackgroundColor: _aiChatPrimary.withValues(
                      alpha: 0.35,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  child: _isWarmingUp
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _aiChatBackground,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Conectando...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: _aiChatBackground,
                          ),
                        )
                      : const Text('Enviar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactLegalNotice extends StatelessWidget {
  const _CompactLegalNotice();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showFullNotice(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _aiChatSecondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _aiChatPrimary,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aviso de uso y privacidad: El asistente es experimental...',
                style: GoogleFonts.plusJakartaSans(
                  color: _aiChatMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Ver más',
              style: GoogleFonts.plusJakartaSans(
                color: _aiChatPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullNotice(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _aiChatCard,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, ScrollController scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _aiChatPrimary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: _aiChatPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            LegalStrings.aiChatNoticeTitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: _aiChatForeground,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        LegalStrings.aiChatNoticeBody,
                        style: GoogleFonts.plusJakartaSans(
                          color: _aiChatForeground.withValues(alpha: 0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: _aiChatPrimary,
                          foregroundColor: _aiChatBackground,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Entendido',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BubbleCard extends StatelessWidget {
  const _BubbleCard({
    required this.label,
    required this.backgroundColor,
    this.text,
    this.placeholder,
    this.isError = false,
    this.sessions = const [],
  });

  final String label;
  final String? text;
  final String? placeholder;
  final Color backgroundColor;
  final bool isError;
  final List<AudioSession> sessions;

  @override
  Widget build(BuildContext context) {
    final bool hasText = text != null && text!.trim().isNotEmpty;
    final String rawContent = hasText ? text! : (placeholder ?? '');
    final ChatResponseViewData formattedContent =
        formatChatResponseForDisplay(rawContent);
    final String? sessionId = formattedContent.recommendationId;
    final String cleanText = formattedContent.text;
    final AudioSession? recommendedSession = _findSession(sessionId);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: _aiChatMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              if (hasText && !isError && label == 'RESPUESTA')
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: _aiChatPrimary,
                  size: 12,
                ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            cleanText,
            style: GoogleFonts.plusJakartaSans(
              color: hasText
                  ? (isError ? const Color(0xFFF2B4B8) : _aiChatForeground)
                  : _aiChatMuted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          if (recommendedSession != null) ...[
            const SizedBox(height: 18),
            _DirectRecommendationTile(session: recommendedSession),
          ],
        ],
      ),
    );
  }

  AudioSession? _findSession(String? recommendation) {
    if (recommendation == null) return null;
    final String query = recommendation.toLowerCase().trim();

    // 1. Intento por ID exacto (incluyendo IDs de Firestore si coinciden)
    final idMatch =
        sessions.where((s) => s.id.toLowerCase() == query).firstOrNull;
    if (idMatch != null) return idMatch;

    // 2. Intento por Título exacto
    final titleMatch =
        sessions.where((s) => s.title.toLowerCase() == query).firstOrNull;
    if (titleMatch != null) return titleMatch;

    // 3. Mapeo resiliente para claves conocidas del Prompt (session_1...4)
    // Esto asegura que si el prompt dice "session_1" funcione aunque el ID en Firestore sea un UUID,
    // siempre que encuentre una sesión que contenga el patrón clave en su título.
    if (query == 'session_1') return _findByTitlePart('5-4-3-2-1');
    if (query == 'session_2') return _findByTitlePart('Ansiedad');
    if (query == 'session_3') return _findByTitlePart('4-6');
    if (query == 'session_4') return _findByTitlePart('Dormir');

    return null;
  }

  AudioSession? _findByTitlePart(String part) {
    final search = part.toLowerCase();
    return sessions
        .where((s) => s.title.toLowerCase().contains(search))
        .firstOrNull;
  }
}

class _DirectRecommendationTile extends StatelessWidget {
  const _DirectRecommendationTile({required this.session});

  final AudioSession session;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SessionPlayerScreen(session: session),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _aiChatPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _aiChatPrimary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _aiChatPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: _aiChatPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SESIÓN RECOMENDADA',
                      style: GoogleFonts.plusJakartaSans(
                        color: _aiChatPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.title,
                      style: GoogleFonts.plusJakartaSans(
                        color: _aiChatForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _aiChatPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Escuchar',
                  style: GoogleFonts.plusJakartaSans(
                    color: _aiChatBackground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
