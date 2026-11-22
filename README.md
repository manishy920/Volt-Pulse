# VoltPulse ⚡

An Android-first Flutter app that monitors battery health and shows live charging details with an animated neon UI.

## Run

```bash
flutter pub get
flutter run            # on a connected Android device (API 26+)
flutter test           # domain-logic unit tests
```

> Test on a **real phone**. Emulators report fake battery values (no current, fixed temperature), so wattage, speed, and estimates won't mean much there.

## Architecture (Clean Architecture + Bloc)

```
lib/
├── main.dart / app.dart              # bootstrap, MultiBlocProvider, theme + locale
├── core/
│   ├── di/injection.dart             # get_it wiring
│   ├── l10n/                         # map-based i18n: English, Hindi, Marathi
│   ├── theme/app_theme.dart          # neon palette, dark / light / AMOLED, VoltPalette extension
│   └── utils/formatters.dart         # °C/°F, mA/A, durations, bytes
├── domain/                           # pure Dart, no Flutter imports
│   ├── entities/                     # BatterySnapshot, PowerEvent, ChargingSession, HistoryPoint, AppSettings, insights…
│   ├── repositories/                 # abstract contracts
│   └── usecases/
│       ├── charging_analytics.dart   # speed class, charger rating, time-to-full / 80 %, discharge ETA, slow-charge detector
│       ├── health_calculator.dart    # 0–100 health score + advice
│       ├── usage_analytics.dart      # idle vs active drain, screen-on time, weekly habits, CSV
│       └── usecases.dart             # thin repository use cases
├── data/
│   ├── datasources/                  # MethodChannel / EventChannel wrapper, SharedPreferences
│   ├── models/mappers.dart           # channel maps → entities
│   └── repositories/                 # implementations
└── presentation/
    ├── blocs/                        # BatteryBloc, SettingsCubit, HistoryCubit, HealthCubit, DeviceCubit
    ├── screens/                      # shell, home, charging overlay, health, history, device, settings, always-on
    └── widgets/                      # gauge, glass card, speed meter, liquid fill, lightning bolt, cyber rings, share card…

android/app/src/main/kotlin/com/voltpulse/voltpulse/
├── MainActivity.kt          # channels: voltpulse/methods, voltpulse/battery, voltpulse/power
├── BatteryMonitor.kt        # process-wide receiver (BATTERY_CHANGED, POWER_CONNECTED/DISCONNECTED) + polling
├── BatteryReader.kt         # BatteryManager + sysfs, normalizes vendor quirks (µA/mA, current sign, µAh/mAh)
├── HistoryStore.kt          # native history: samples, sessions, daily capacity (records while UI is closed)
├── AlertManager.kt          # charge-level / full / overheat alarms, plug sound + vibration
├── BatteryMonitorService.kt # foreground service + live "% · W" notification
├── BatteryWidgetProvider.kt # home-screen widget
├── BootReceiver.kt, AlarmActionReceiver.kt, DeviceInfoReader.kt, MediaExporter.kt, NativeSettings.kt
```

## Notes and platform limits

- **Decimal %**: Android only reports whole-number levels. VoltPulse divides `CHARGE_COUNTER` by a learned full-capacity estimate, which it refines each time the level ticks over. Expect it to settle after a few % of use.
- **Health score** is an *estimate* built from capacity vs design, temperature history, charge habits, and cycles. Android doesn't give apps a real state-of-health value.
- **Design capacity** is read via `PowerProfile` (hidden API) or `charge_full_design`. On some phones neither is readable, and the screen shows `--`.
- **Cycle count** needs Android 14+ (`EXTRA_CYCLE_COUNT`) or a readable sysfs node.
- **Background recording and alarms** need the *Live notification* setting (a foreground service). Without it, data is only recorded while the app process is alive.
- **Screen-on time** is VoltPulse's own measurement. The system figure needs Usage Access, so it isn't used.
- **Share images** need Android 10+ (MediaStore). CSV exports go to `Downloads/VoltPulse`.
- The foreground service uses type `specialUse`. A Play Store release has to justify it in the Play Console.
