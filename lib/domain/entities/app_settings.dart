import 'package:equatable/equatable.dart';

enum AppThemeMode { dark, light, amoled }

enum AnimationTheme { lightning, liquid, cyberRing, minimal }

enum TempUnit { celsius, fahrenheit }

enum CurrentUnit { milliamp, amp }

enum AppLanguage { en, hi, mr }

class AppSettings extends Equatable {
  final AppThemeMode themeMode;
  final AnimationTheme animationTheme;
  final TempUnit tempUnit;
  final CurrentUnit currentUnit;
  final AppLanguage language;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool showOverlayOnPlug;
  final bool chargeAlarmEnabled;
  final int chargeAlarmLevel;
  final bool fullAlarmEnabled;
  final bool overheatEnabled;
  final double overheatThresholdC;
  final bool liveNotification;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.animationTheme = AnimationTheme.lightning,
    this.tempUnit = TempUnit.celsius,
    this.currentUnit = CurrentUnit.milliamp,
    this.language = AppLanguage.en,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.showOverlayOnPlug = true,
    this.chargeAlarmEnabled = true,
    this.chargeAlarmLevel = 80,
    this.fullAlarmEnabled = true,
    this.overheatEnabled = true,
    this.overheatThresholdC = 40,
    this.liveNotification = false,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AnimationTheme? animationTheme,
    TempUnit? tempUnit,
    CurrentUnit? currentUnit,
    AppLanguage? language,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? showOverlayOnPlug,
    bool? chargeAlarmEnabled,
    int? chargeAlarmLevel,
    bool? fullAlarmEnabled,
    bool? overheatEnabled,
    double? overheatThresholdC,
    bool? liveNotification,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        animationTheme: animationTheme ?? this.animationTheme,
        tempUnit: tempUnit ?? this.tempUnit,
        currentUnit: currentUnit ?? this.currentUnit,
        language: language ?? this.language,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        showOverlayOnPlug: showOverlayOnPlug ?? this.showOverlayOnPlug,
        chargeAlarmEnabled: chargeAlarmEnabled ?? this.chargeAlarmEnabled,
        chargeAlarmLevel: chargeAlarmLevel ?? this.chargeAlarmLevel,
        fullAlarmEnabled: fullAlarmEnabled ?? this.fullAlarmEnabled,
        overheatEnabled: overheatEnabled ?? this.overheatEnabled,
        overheatThresholdC: overheatThresholdC ?? this.overheatThresholdC,
        liveNotification: liveNotification ?? this.liveNotification,
      );

  @override
  List<Object?> get props => [themeMode, animationTheme, tempUnit, currentUnit, language, soundEnabled,
        hapticsEnabled, showOverlayOnPlug, chargeAlarmEnabled, chargeAlarmLevel, fullAlarmEnabled,
        overheatEnabled, overheatThresholdC, liveNotification];
}
