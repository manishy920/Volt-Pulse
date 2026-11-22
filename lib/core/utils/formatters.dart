import 'package:intl/intl.dart';

import '../../domain/entities/app_settings.dart';

/// Unit-aware formatting driven by user settings.
class Fmt {
  final AppSettings settings;
  const Fmt(this.settings);

  bool get fahrenheit => settings.tempUnit == TempUnit.fahrenheit;

  double tempValue(double c) => fahrenheit ? c * 9 / 5 + 32 : c;
  String temp(double c, {int digits = 1}) => '${tempValue(c).toStringAsFixed(digits)}${fahrenheit ? '°F' : '°C'}';
  String get tempUnit => fahrenheit ? '°F' : '°C';

  String current(double ma) => settings.currentUnit == CurrentUnit.amp
      ? '${(ma / 1000).toStringAsFixed(2)} A'
      : '${ma.round()} mA';

  static String watts(double w) => '${w.toStringAsFixed(w >= 10 ? 1 : 2)} W';
  static String volts(double v) => '${v.toStringAsFixed(3)} V';
  static String percent(double p, {int digits = 2}) => '${p.toStringAsFixed(digits)}%';

  static String duration(Duration? d, {String unknown = '--'}) {
    if (d == null) return unknown;
    if (d.inMinutes < 1) return '<1m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h >= 24) return '${d.inDays}d ${h % 24}h';
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  static String bytes(int b) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = b.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
  }

  static String time(DateTime t) => DateFormat('HH:mm').format(t);
  static String dateTime(DateTime t) => DateFormat('d MMM, HH:mm').format(t);
}
