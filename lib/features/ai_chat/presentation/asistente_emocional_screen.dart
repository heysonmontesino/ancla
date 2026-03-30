import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../core/legal/legal_strings.dart';
import '../../sessions/data/firestore_audio_repository.dart';
import '../../sessions/models/audio_session.dart';
import '../../sessions/ui/session_player_screen.dart';
import '../data/asistente_emocional_service.dart';

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
  }) : _service = service;

  final AsistenteEmocionalService? _service;

  @override
  State<AsistenteEmocionalScreen> createState() =>
      _AsistenteEmocionalScreenState();
}

class _AsistenteEmocionalScreenState extends State<AsistenteEmocionalScreen> {
  late final AsistenteEmocionalService _service;
  late final bool _ownsService;
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
  late final bool _backendAvailable;

  List<AudioSession> _availableSessions = [];

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? AsistenteEmocionalService();
    _ownsService = widget._service == null;
    _backendAvailable =
        widget._service != null || AsistenteEmocionalService.isConfigured;
    if (_backendAvailable) {
      unawaited(_checkAiConsent());
      unawaited(_loadSessions());
    }
  }

  @override
  void dispose() {
    _replySubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final sessions = await FirestoreAudioRepository.fetchSessions();
    if (mounted) {
      setState(() => _availableSessions = sessions);
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
    final String message = _messageController.text.trim();
    if (message.isEmpty || _isSending) {
      return;
    }

    await _replySubscription?.cancel();

    setState(() {
      _submittedMessage = message;
      _responseText = '';
      _errorText = null;
      _isSending = true;
    });
    _messageController.clear();

    _replySubscription = _service.streamReply(message).listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          _responseText += chunk;
        });
        _scrollToBottom();
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _errorText = error is AsistenteEmocionalException
              ? error.message
              : 'No se pudo conectar con el asistente en este momento.';
          _isSending = false;
        });
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isSending = false;
          if (_responseText.trim().isEmpty && _errorText == null) {
            _errorText =
                'El asistente no devolvió contenido. Intenta de nuevo.';
          }
        });
        _scrollToBottom();
      },
      cancelOnError: false,
    );
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
            style: GoogleFonts.instrumentSans(
              color: _aiChatForeground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          content: Text(
            LegalStrings.aiConsentModalBody,
            style: GoogleFonts.instrumentSans(
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
                textStyle: GoogleFonts.instrumentSans(
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
                textStyle: GoogleFonts.instrumentSans(
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
          children: [
            Text(
              'Chat de apoyo emocional',
              style: GoogleFonts.instrumentSans(
                color: _aiChatForeground,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
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
                style: GoogleFonts.instrumentSans(
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
        child: _backendAvailable ? _buildChat() : _buildUnavailable(),
      ),
    );
  }

  Widget _buildUnavailable() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const _CompactLegalNotice(),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _aiChatCard,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: _aiChatMuted,
                size: 36,
              ),
              const SizedBox(height: 16),
              Text(
                'Chat no disponible en este momento',
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSans(
                  color: _aiChatForeground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'El chat de apoyo emocional no está disponible en esta versión. '
                'Estará activo próximamente.',
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSans(
                  color: _aiChatMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Mientras tanto, puedes usar las sesiones guiadas o el protocolo SOS '
                'si necesitas apoyo inmediato.',
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSans(
                  color: _aiChatMuted.withValues(alpha: 0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
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
                    style: GoogleFonts.instrumentSans(
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
                style: GoogleFonts.instrumentSans(
                  color: _aiChatForeground,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje breve...',
                  hintStyle: GoogleFonts.instrumentSans(
                    color: _aiChatMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: _aiChatCard,
                  contentPadding: const EdgeInsets.all(16),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSending ? null : _sendMessage,
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
                    textStyle: GoogleFonts.instrumentSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  child: _isSending
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
                style: GoogleFonts.instrumentSans(
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
              style: GoogleFonts.instrumentSans(
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
                            style: GoogleFonts.instrumentSans(
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
                        style: GoogleFonts.instrumentSans(
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
                          style: GoogleFonts.instrumentSans(
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

    // Recommendation check
    final String? sessionId = _extractSessionId(rawContent);
    final String cleanText = _removeRecommendationCode(rawContent);
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
                style: GoogleFonts.instrumentSans(
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
            style: GoogleFonts.instrumentSans(
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

  String? _extractSessionId(String content) {
    final regExp = RegExp(r'\[RECOMMEND:(.*?)\]');
    final match = regExp.firstMatch(content);
    return match?.group(1);
  }

  String _removeRecommendationCode(String content) {
    return content.replaceAll(RegExp(r'\n?\[RECOMMEND:.*?\]'), '').trim();
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
                      style: GoogleFonts.instrumentSans(
                        color: _aiChatPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.title,
                      style: GoogleFonts.instrumentSans(
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
                  style: GoogleFonts.instrumentSans(
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
