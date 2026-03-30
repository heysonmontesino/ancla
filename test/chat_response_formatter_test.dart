import 'package:app_pap_respiracion/features/ai_chat/presentation/chat_response_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatChatResponseForDisplay', () {
    test('quita comillas y preserva la recomendacion separada', () {
      final result = formatChatResponseForDisplay(
        '"Me siento contigo."\n\n"Haz solo esto por ahora."\n[RECOMMEND:session_3]',
      );

      expect(result.text, 'Me siento contigo.\n\nHaz solo esto por ahora.');
      expect(result.recommendationId, 'session_3');
    });

    test('quita comillas envolventes sin tocar una respuesta normal', () {
      final result = formatChatResponseForDisplay(
        '“Sentirse solo pesa de verdad. Por ahora apoya los pies en el piso.”',
      );

      expect(
        result.text,
        'Sentirse solo pesa de verdad. Por ahora apoya los pies en el piso.',
      );
      expect(result.recommendationId, isNull);
    });

    test('preserva un parrafo breve sin deformar el cuerpo principal', () {
      final result = formatChatResponseForDisplay(
        'No dejo de pensar en esa persona.\n\nQuédate con una sola idea.\nMira algo fijo diez segundos.',
      );

      expect(
        result.text,
        'No dejo de pensar en esa persona.\n\nQuédate con una sola idea.\nMira algo fijo diez segundos.',
      );
    });
  });
}
