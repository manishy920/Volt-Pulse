import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';

class SettingsLocalDataSource {
  final SharedPreferences prefs;
  SettingsLocalDataSource(this.prefs);

  T _enum<T extends Enum>(List<T> values, String key, T fallback) {
    final name = prefs.getString(key);
    return values.firstWhere((v) => v.name == name, orElse: () => fallback);
  }

  AppSettings read() {
    const d = AppSettings();
    return AppSettings(
      themeMode: _enum(AppThemeMode.values, 'themeMode', d.themeMode),
      animationTheme: _enum(AnimationTheme.values, 'animationTheme', d.animationTheme),
      tempUnit: _enum(TempUnit.values, 'tempUnit', d.tempUnit),
      currentUnit: _enum(CurrentUnit.values, 'currentUnit', d.currentUnit),
      language: _enum(AppLanguage.values, 'language', d.language),
      soundEnabled: prefs.getBool('soundEnabled') ?? d.soundEnabled,
      hapticsEnabled: prefs.getBool('hapticsEnabled') ?? d.hapticsEnabled,
      showOverlayOnPlug: prefs.getBool('showOverlayOnPlug') ?? d.showOverlayOnPlug,
      chargeAlarmEnabled: prefs.getBool('chargeAlarmEnabled') ?? d.chargeAlarmEnabled,
      chargeAlarmLevel: prefs.getInt('chargeAlarmLevel') ?? d.chargeAlarmLevel,
      fullAlarmEnabled: prefs.getBool('fullAlarmEnabled') ?? d.fullAlarmEnabled,
      overheatEnabled: prefs.getBool('overheatEnabled') ?? d.overheatEnabled,
      overheatThresholdC: prefs.getDouble('overheatThresholdC') ?? d.overheatThresholdC,
      liveNotification: prefs.getBool('liveNotification') ?? d.liveNotification,
    );
  }

  Future<void> write(AppSettings s) async {
    await Future.wait([
      prefs.setString('themeMode', s.themeMode.name),
      prefs.setString('animationTheme', s.animationTheme.name),
      prefs.setString('tempUnit', s.tempUnit.name),
      prefs.setString('currentUnit', s.currentUnit.name),
      prefs.setString('language', s.language.name),
      prefs.setBool('soundEnabled', s.soundEnabled),
      prefs.setBool('hapticsEnabled', s.hapticsEnabled),
      prefs.setBool('showOverlayOnPlug', s.showOverlayOnPlug),
      prefs.setBool('chargeAlarmEnabled', s.chargeAlarmEnabled),
      prefs.setInt('chargeAlarmLevel', s.chargeAlarmLevel),
      prefs.setBool('fullAlarmEnabled', s.fullAlarmEnabled),
      prefs.setBool('overheatEnabled', s.overheatEnabled),
      prefs.setDouble('overheatThresholdC', s.overheatThresholdC),
      prefs.setBool('liveNotification', s.liveNotification),
    ]);
  }
}
