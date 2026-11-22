import '../entities/history.dart';
import '../entities/insights.dart';

/// Drain rate (idle vs active), screen-on time since unplug and the weekly habits report.
class UsageAnalytics {
  const UsageAnalytics();

  DrainStats drain(List<HistoryPoint> points) {
    double activeDrop = 0, activeHours = 0, idleDrop = 0, idleHours = 0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (a.charging || b.charging) continue;
      final hours = b.time.difference(a.time).inSeconds / 3600;
      if (hours <= 0 || hours > 1) continue; // gap → process was dead
      final drop = a.level - b.level;
      if (drop < 0) continue; // plugged in between samples
      if (a.screenOn) {
        activeDrop += drop;
        activeHours += hours;
      } else {
        idleDrop += drop;
        idleHours += hours;
      }
    }

    // Screen-on time since the last time the phone was unplugged.
    var screenOn = Duration.zero;
    for (var i = points.length - 1; i > 0; i--) {
      final a = points[i - 1], b = points[i];
      if (a.charging) break;
      final gap = b.time.difference(a.time);
      if (a.screenOn && gap < const Duration(hours: 1)) screenOn += gap;
    }

    return DrainStats(
      activePerHour: activeHours >= 0.25 ? activeDrop / activeHours : null,
      idlePerHour: idleHours >= 0.5 ? idleDrop / idleHours : null,
      screenOnSinceUnplug: screenOn,
    );
  }

  HabitsReport weekly(HistoryBundle h, {DateTime? now}) {
    final since = (now ?? DateTime.now()).subtract(const Duration(days: 7));
    final sessions = h.sessions.where((s) => s.end.isAfter(since)).toList();
    final full = sessions.where((s) => s.endLevel >= 99).length;
    final healthy = sessions.where((s) => s.startLevel >= 15 && s.endLevel <= 85).length;

    // Count distinct times the battery dipped to ≤5% (a new dip needs a recovery above 10% in between).
    var deep = 0;
    var armed = true;
    for (final p in h.points.where((p) => p.time.isAfter(since))) {
      if (armed && p.level <= 5) {
        deep++;
        armed = false;
      } else if (p.level > 10) {
        armed = true;
      }
    }
    final avgEnd = sessions.isEmpty ? 0.0 : sessions.map((s) => s.endLevel).reduce((a, b) => a + b) / sessions.length;
    final total = sessions.fold(Duration.zero, (d, s) => d + s.duration);

    final parts = <String>[];
    if (sessions.isEmpty) {
      parts.add('No charging sessions recorded this week yet.');
    } else {
      parts.add('You charged ${sessions.length} time${sessions.length == 1 ? '' : 's'} this week');
      if (full > 0) parts.add('reached 100% $full time${full == 1 ? '' : 's'}');
      if (deep > 0) parts.add('let it hit 0–5% $deep time${deep == 1 ? '' : 's'}');
    }
    var summary = '${parts.join(', ')}.';
    if (full > 0 || deep > 0) {
      summary += ' Try keeping it between 20% and 80%.';
    } else if (sessions.isNotEmpty) {
      summary += ' Great habits — keep it up!';
    }

    return HabitsReport(
      sessions: sessions.length,
      fullCharges: full,
      deepDischarges: deep,
      healthyRangeSessions: healthy,
      avgEndLevel: avgEnd,
      totalChargeTime: total,
      summary: summary,
    );
  }

  String toCsv(HistoryBundle h) {
    final b = StringBuffer()
      ..writeln('# VoltPulse export ${DateTime.now().toIso8601String()}')
      ..writeln('# Battery samples')
      ..writeln('timestamp,level_percent,temperature_c,current_ma,charging,screen_on');
    for (final p in h.points) {
      b.writeln('${p.time.toIso8601String()},${p.level},${p.temperatureC},${p.currentMa},${p.charging},${p.screenOn}');
    }
    b
      ..writeln()
      ..writeln('# Charging sessions')
      ..writeln('start,end,duration_min,start_percent,end_percent,avg_w,peak_w,max_temp_c,charger,label');
    for (final s in h.sessions) {
      final label = (s.label ?? '').replaceAll('"', "'");
      b.writeln('${s.start.toIso8601String()},${s.end.toIso8601String()},${s.duration.inMinutes},'
          '${s.startLevel.toStringAsFixed(1)},${s.endLevel.toStringAsFixed(1)},${s.avgWatts.toStringAsFixed(2)},'
          '${s.peakWatts.toStringAsFixed(2)},${s.maxTempC.toStringAsFixed(1)},${s.charger.name},"$label"');
    }
    b
      ..writeln()
      ..writeln('# Capacity (wear tracker)')
      ..writeln('date,full_capacity_mah');
    for (final c in h.capacity) {
      b.writeln('${c.time.toIso8601String()},${c.mah.toStringAsFixed(0)}');
    }
    return b.toString();
  }
}
