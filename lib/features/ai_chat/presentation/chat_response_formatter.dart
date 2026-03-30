class ChatResponseViewData {
  const ChatResponseViewData({
    required this.text,
    this.recommendationId,
  });

  final String text;
  final String? recommendationId;
}

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
    RegExp(r'\n?\[RECOMMEND:.*?\]'),
    '',
  );

  final String normalizedText = _normalizeBodyText(contentWithoutRecommendation);

  return ChatResponseViewData(
    text: normalizedText,
    recommendationId: recommendationId,
  );
}

String? _extractRecommendationId(String content) {
  final Match? match = RegExp(r'\[RECOMMEND:(.*?)\]').firstMatch(content);
  final String? recommendationId = match?.group(1)?.trim();

  if (recommendationId == null || recommendationId.isEmpty) {
    return null;
  }

  return recommendationId;
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
