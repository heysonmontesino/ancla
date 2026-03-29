import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';
import 'models/ai_tone_preference.dart';

class ProfilePreferencesRepository {
  ProfilePreferencesRepository._();

  static const String _aiToneKey = PrefsKeys.aiTonePreference;
  static const String _aiChatConsentKey = PrefsKeys.aiChatConsentAccepted;

  /// Persiste el tono de IA elegido por el usuario.
  static Future<void> saveAiTone(AiTonePreference tone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_aiToneKey, tone.storageKey);
    } catch (e) {
      // SharedPreferences no debería fallar en condiciones normales.
      rethrow;
    }
  }

  /// Lee el tono guardado. Devuelve [AiTonePreference.empathic] si no hay valor.
  static Future<AiTonePreference> getAiTone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_aiToneKey);
      if (stored == null) return AiTonePreference.empathic;
      return AiTonePreferenceLabel.fromStorageKey(stored);
    } catch (e) {
      return AiTonePreference.empathic;
    }
  }

  /// Elimina el consentimiento del chat de IA para que se muestre el diálogo
  /// de nuevo en la próxima entrada a la pantalla del asistente.
  static Future<void> resetAiChatConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_aiChatConsentKey);
    } catch (e) {
      rethrow;
    }
  }
}
