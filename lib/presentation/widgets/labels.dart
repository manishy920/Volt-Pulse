import 'package:flutter/material.dart';

import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/battery_snapshot.dart';
import '../../domain/entities/insights.dart';

/// Localized labels / colors / icons for domain enums.
extension SnapshotLabels on BatterySnapshot {
  String statusLabel(BuildContext c) {
    if (isFull) return c.tr('status_full');
    if (isCharging) return c.tr('status_charging');
    if (isPluggedIn) return c.tr('status_not_charging');
    return c.tr('status_discharging');
  }

  IconData get statusIcon => isFull
      ? Icons.battery_full_rounded
      : isCharging
          ? Icons.bolt_rounded
          : Icons.battery_std_rounded;
}

String chargerLabel(BuildContext c, ChargerType t) => switch (t) {
      ChargerType.ac => c.tr('charger_ac'),
      ChargerType.usb => c.tr('charger_usb'),
      ChargerType.wireless => c.tr('charger_wireless'),
      ChargerType.dock => c.tr('charger_dock'),
      ChargerType.none => c.tr('charger_none'),
    };

IconData chargerIcon(ChargerType t) => switch (t) {
      ChargerType.ac => Icons.power_rounded,
      ChargerType.usb => Icons.usb_rounded,
      ChargerType.wireless => Icons.wifi_tethering_rounded,
      ChargerType.dock => Icons.dock_rounded,
      ChargerType.none => Icons.power_off_rounded,
    };

String healthLabel(BuildContext c, BatteryHealth h) => c.tr('health_${h.name}');

String speedLabel(BuildContext c, ChargingSpeed s) => c.tr('speed_${s.name}');

Color speedColor(ChargingSpeed s) => switch (s) {
      ChargingSpeed.slow => Neon.amber,
      ChargingSpeed.fast => Neon.green,
      ChargingSpeed.superFast => Neon.purple,
    };

String ratingLabel(BuildContext c, ChargerRating r) => c.tr('rating_${r.name}');

Color ratingColor(ChargerRating r) => switch (r) {
      ChargerRating.weak => Neon.red,
      ChargerRating.good => Neon.amber,
      ChargerRating.excellent => Neon.green,
    };

Color healthStatusColor(HealthStatus s) => switch (s) {
      HealthStatus.excellent => Neon.green,
      HealthStatus.good => Neon.cyan,
      HealthStatus.fair => Neon.amber,
      HealthStatus.poor => Neon.red,
    };
