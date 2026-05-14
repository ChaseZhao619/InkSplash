import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LanguagePreference {
  system,
  zh,
  en;

  Locale? get locale {
    return switch (this) {
      LanguagePreference.system => null,
      LanguagePreference.zh => const Locale('zh'),
      LanguagePreference.en => const Locale('en'),
    };
  }
}

class LanguagePreferenceStore {
  const LanguagePreferenceStore();

  static const _key = 'language_preference';

  Future<LanguagePreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return LanguagePreference.values.firstWhere(
      (item) => item.name == value,
      orElse: () => LanguagePreference.system,
    );
  }

  Future<void> save(LanguagePreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, preference.name);
  }
}
