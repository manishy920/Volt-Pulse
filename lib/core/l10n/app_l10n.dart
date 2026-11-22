import 'package:flutter/widgets.dart';

import '../../domain/entities/app_settings.dart';
import 'strings_en.dart';
import 'strings_hi.dart';
import 'strings_mr.dart';

/// Lightweight map-based localization (English, Hindi, Marathi). Missing keys fall back to English.
class AppL10n {
  final AppLanguage language;
  const AppL10n(this.language);

  static const supportedLocales = [Locale('en'), Locale('hi'), Locale('mr')];

  static AppL10n of(BuildContext context) => Localizations.of<AppL10n>(context, AppL10n) ?? const AppL10n(AppLanguage.en);

  static AppLanguage languageOf(Locale l) => AppLanguage.values.firstWhere((v) => v.name == l.languageCode, orElse: () => AppLanguage.en);

  Map<String, String> get _table => switch (language) {
        AppLanguage.en => stringsEn,
        AppLanguage.hi => stringsHi,
        AppLanguage.mr => stringsMr,
      };

  String t(String key) => _table[key] ?? stringsEn[key] ?? key;
}

class AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const AppL10nDelegate();

  @override
  bool isSupported(Locale locale) => AppL10n.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppL10n> load(Locale locale) async => AppL10n(AppL10n.languageOf(locale));

  @override
  bool shouldReload(AppL10nDelegate old) => false;
}

extension L10nContext on BuildContext {
  String tr(String key) => AppL10n.of(this).t(key);
}
