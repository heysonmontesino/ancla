import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/prefs_keys.dart';

class OnboardingService {
  OnboardingService._();

  static const String _key = PrefsKeys.onboardingComplete;

  static Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
