enum AiTonePreference { empathic, directive, clinical }

extension AiTonePreferenceLabel on AiTonePreference {
  String get label {
    switch (this) {
      case AiTonePreference.empathic:
        return 'Cálido';
      case AiTonePreference.directive:
        return 'Directo';
      case AiTonePreference.clinical:
        return 'Clínico';
    }
  }

  String get description {
    switch (this) {
      case AiTonePreference.empathic:
        return 'Respuestas cálidas que validan tus emociones.';
      case AiTonePreference.directive:
        return 'Orientación clara con pasos concretos a seguir.';
      case AiTonePreference.clinical:
        return 'Lenguaje preciso y neutro, sin adornos emocionales.';
    }
  }

  String get storageKey => name;

  static AiTonePreference fromStorageKey(String key) {
    return AiTonePreference.values.firstWhere(
      (e) => e.name == key,
      orElse: () => AiTonePreference.empathic,
    );
  }
}
