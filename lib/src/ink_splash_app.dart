import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization/app_strings.dart';
import 'settings/language_preference.dart';
import 'theme/ink_theme.dart';
import 'ui/app_shell.dart';

class InkSplashApp extends StatefulWidget {
  const InkSplashApp({super.key});

  @override
  State<InkSplashApp> createState() => _InkSplashAppState();
}

class _InkSplashAppState extends State<InkSplashApp> {
  final _store = const LanguagePreferenceStore();
  LanguagePreference _language = LanguagePreference.system;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final preference = await _store.load();
    if (mounted) {
      setState(() => _language = preference);
    }
  }

  Future<void> _setLanguage(LanguagePreference preference) async {
    setState(() => _language = preference);
    await _store.save(preference);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InkSplash',
      debugShowCheckedModeBanner: false,
      theme: InkTheme.light(),
      locale: _language.locale,
      supportedLocales: AppStrings.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) {
          return const Locale('en');
        }
        return supportedLocales.firstWhere(
          (supported) => supported.languageCode == locale.languageCode,
          orElse: () => const Locale('en'),
        );
      },
      localizationsDelegates: const [
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: AppShell(language: _language, onLanguageChanged: _setLanguage),
    );
  }
}
