class ChatResponseViewData {
  const ChatResponseViewData({
    required this.text,
    this.recommendationId,
  });

  final String text;
  final String? recommendationId;
}

final RegExp _recommendationTagPattern = RegExp(
  r'[\[\(]\s*RECOMMEND\s*:\s*([^) \]\r\n]+)\s*[\]\)]',
  caseSensitive: false,
);
final RegExp _explicitNonSpanishRequestPattern = RegExp(
  r'\b(en ingles|en inglés|in english|english please|respond in english|reply in english)\b',
  caseSensitive: false,
);
final RegExp _spanishSignalPattern = RegExp(
  r'[áéíóúñ¿¡]|\b(me|mi|mis|estoy|siento|quiero|trabajo|persona|mal|solo|sola|triste|enojado|enojada|ansiedad|por|para|porque|que|con|una|ahora|dejar|eso|suena|pesa|mucho|duele|rabia|tristeza|cansancio|paso|hoy|como|qué|no|dejo|pensar|pienso|pensando|esa|esta|trato|trataron|frustrado|frustrada|pareja|enojo|estresado|estresada)\b',
  caseSensitive: false,
);
final RegExp _englishSignalPattern = RegExp(
  r"\b(the|and|you|your|you're|are|with|that|this|can|feel|feels|try|breathe|want|what|more|about|work|person|now|slowly|sounds|sound|painful|heavy|hurts|hurt|alone|angry|sad|right|tell|step)\b",
  caseSensitive: false,
);
final RegExp _englishPhrasePattern = RegExp(
  r"\b(that sounds|it sounds|try to|tell me|right now|what hurts|what feels|you can|let's|i'm|you're|take a breath)\b",
  caseSensitive: false,
);

ChatResponseViewData formatChatResponseForDisplay(String rawContent) {
  final String normalizedInput = rawContent
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();

  if (normalizedInput.isEmpty) {
    return const ChatResponseViewData(text: '');
  }

  final String? recommendationId = _extractRecommendationId(normalizedInput);
  final String contentWithoutRecommendation = normalizedInput.replaceAll(
    RegExp(r'\s*[\[\(]\s*RECOMMEND\s*:\s*.*?[\]\)]', caseSensitive: false),
    '',
  );

  final String normalizedText = _normalizeBodyText(contentWithoutRecommendation);

  return ChatResponseViewData(
    text: normalizedText,
    recommendationId: recommendationId,
  );
}

String? _extractRecommendationId(String content) {
  final Match? match = _recommendationTagPattern.firstMatch(content);
  final String? recommendationId = match?.group(1)?.trim();

  if (recommendationId == null || recommendationId.isEmpty) {
    return null;
  }

  return recommendationId.replaceAll('\\', '');
}

String _stripWrappingQuotes(String value) {
  String result = value.trim();
  const quotePairs = <String, String>{
    '"': '"',
    '\'': '\'',
    '“': '”',
    '‘': '’',
  };

  bool changed = true;
  while (changed && result.length >= 2) {
    changed = false;
    for (final entry in quotePairs.entries) {
      if (result.startsWith(entry.key) && result.endsWith(entry.value)) {
        result = result.substring(1, result.length - 1).trim();
        changed = true;
        break;
      }
    }
  }

  return result;
}

String _normalizeBodyText(String content) {
  final List<String> outputLines = <String>[];
  bool previousWasBlank = false;

  for (final rawLine in content.split('\n')) {
    final String cleanedLine = _stripWrappingQuotes(
      rawLine.replaceAll(RegExp(r'[ \t]+'), ' ').trim(),
    );

    if (cleanedLine.isEmpty) {
      if (!previousWasBlank && outputLines.isNotEmpty) {
        outputLines.add('');
      }
      previousWasBlank = true;
      continue;
    }

    outputLines.add(cleanedLine);
    previousWasBlank = false;
  }

  return _stripWrappingQuotes(outputLines.join('\n').trim());
}

bool shouldRejectUnexpectedEnglishResponse({
  required String userMessage,
  required String responseText,
}) {
  if (_explicitNonSpanishRequestPattern.hasMatch(userMessage)) {
    return false;
  }

  if (!_looksSpanish(userMessage)) {
    return false;
  }

  final String normalizedResponse = responseText.trim();
  if (normalizedResponse.isEmpty) {
    return false;
  }

  final int spanishMatches = _countPatternMatches(
    _spanishSignalPattern,
    normalizedResponse,
  );
  final int englishMatches = _countPatternMatches(
    _englishSignalPattern,
    normalizedResponse,
  );
  final bool hasEnglishPhrase = _englishPhrasePattern.hasMatch(
    normalizedResponse,
  );

  if (spanishMatches >= 2) {
    return false;
  }

  if (englishMatches >= 2) {
    return true;
  }

  if (hasEnglishPhrase) {
    return true;
  }

  return englishMatches >= 1 && spanishMatches == 0;
}

bool _looksSpanish(String value) {
  return _countPatternMatches(_spanishSignalPattern, value) >= 2;
}

int _countPatternMatches(RegExp pattern, String value) {
  return pattern.allMatches(value).length;
}
