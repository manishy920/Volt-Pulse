import 'package:flutter_test/flutter_test.dart';
import 'package:voltpulse/data/models/mappers.dart';
import 'package:voltpulse/domain/entities/battery_snapshot.dart';
import 'package:voltpulse/domain/entities/history.dart';
import 'package:voltpulse/domain/entities/insights.dart';
import 'package:voltpulse/domain/usecases/charging_analytics.dart';
import 'package:voltpulse/domain/usecases/health_calculator.dart';
import 'package:voltpulse/domain/usecases/usage_analytics.dart';

BatterySnapshot snap({
  double percent = 50,
  ChargerType charger = ChargerType.ac,
  double currentMa = 2000,
  int voltageMv = 4000,
  double temp = 30,
  double? full = 4000,
  double? design = 5000,
  ActiveSession? session,
}) =>
    BatterySnapshot(
      level: percent.floor(),
      percent: percent,
      status: charger == ChargerType.none ? ChargeStatus.discharging : ChargeStatus.charging,
      charger: charger,
      voltageMv: voltageMv,
      currentMa: currentMa,
      temperatureC: temp,
      technology: 'Li-ion',
      health: BatteryHealth.good,
      timestamp: DateTime.now(),
      chargeCounterMah: full == null ? null : full * percent / 100,
      fullCapacityMah: full,
      designCapacityMah: design,
      session: session,
    );

ChargingSession session(DateTime end, {double start = 30, double endLvl = 80, double avg = 15, ChargerType c = ChargerType.ac, String? label}) =>
    ChargingSession(
      id: '${end.millisecondsSinceEpoch}',
      start: end.subtract(const Duration(minutes: 40)),
      end: end,
      startLevel: start,
      endLevel: endLvl,
      avgWatts: avg,
      peakWatts: avg * 1.5,
      maxTempC: 35,
      charger: c,
      label: label,
    );

void main() {
  const a = ChargingAnalytics();

  group('ChargingAnalytics', () {
    test('classifies speed at the spec boundaries', () {
      expect(a.classifySpeed(9.9), ChargingSpeed.slow);
      expect(a.classifySpeed(10), ChargingSpeed.fast);
      expect(a.classifySpeed(25), ChargingSpeed.fast);
      expect(a.classifySpeed(25.1), ChargingSpeed.superFast);
    });

    test('rates chargers', () {
      expect(a.rateCharger(5), ChargerRating.weak);
      expect(a.rateCharger(12), ChargerRating.good);
      expect(a.rateCharger(30), ChargerRating.excellent);
    });

    test('power is V × |A|', () {
      expect(snap(voltageMv: 5000, currentMa: -2000).powerW, closeTo(10, 1e-9));
    });

    test('time to 80% at 2000 mA from 50% of 4000 mAh is 36 min', () {
      expect(a.timeToLevel(snap(), 80), const Duration(minutes: 36));
    });

    test('time to full adds a slower taper phase above 80%', () {
      final to80 = a.timeToLevel(snap(), 80)!;
      final full = a.timeToLevel(snap(), 100)!;
      // 20% of 4000 mAh at 45% of 2000 mA = 0.888h ≈ 53 min
      expect((full - to80).inSeconds, closeTo(const Duration(minutes: 53).inSeconds, 60));
    });

    test('discharge estimate uses charge counter / current', () {
      final s = snap(charger: ChargerType.none, currentMa: -500, percent: 50);
      expect(a.dischargeRemaining(s), const Duration(hours: 4));
    });

    test('slow-charge detector flags a session far below the best charger of that type', () {
      final now = DateTime.now();
      final history = [session(now.subtract(const Duration(days: 1)), avg: 20), session(now.subtract(const Duration(days: 2)), avg: 18)];
      final live = ActiveSession(
        id: 'x',
        start: now.subtract(const Duration(minutes: 5)),
        startLevel: 30,
        avgWatts: 6,
        peakWatts: 7,
        maxTempC: 30,
        charger: ChargerType.ac,
      );
      expect(a.slowChargeBaseline(snap(session: live), history), 20);
      final ok = ActiveSession(id: 'y', start: live.start, startLevel: 30, avgWatts: 15, peakWatts: 18, maxTempC: 30, charger: ChargerType.ac);
      expect(a.slowChargeBaseline(snap(session: ok), history), isNull);
    });

    test('groups chargers by label for comparison', () {
      final now = DateTime.now();
      final list = a.compareChargers([
        session(now, avg: 20, label: 'Brick'),
        session(now, avg: 22, label: 'Brick'),
        session(now, avg: 5, c: ChargerType.usb),
      ]);
      expect(list.first.name, 'Brick');
      expect(list.first.avgWatts, 21);
      expect(list.last.rating, ChargerRating.weak);
    });
  });

  group('HealthCalculator', () {
    test('healthy battery scores high, worn + hot battery scores low', () {
      const calc = HealthCalculator();
      final good = calc.compute(snap(full: 4900, design: 5000, temp: 28), const HistoryBundle());
      expect(good.score, greaterThanOrEqualTo(85));
      expect(good.status, HealthStatus.excellent);

      final now = DateTime.now();
      final hotPoints = [
        for (var i = 0; i < 20; i++)
          HistoryPoint(time: now.subtract(Duration(minutes: i * 5)), level: 50, temperatureC: 44, currentMa: 0, charging: false, screenOn: true),
      ];
      final bad = calc.compute(snap(full: 3200, design: 5000, temp: 44), HistoryBundle(points: hotPoints));
      expect(bad.score, lessThan(50));
      expect(bad.advice, containsAll(['advice_capacity_low', 'advice_heat']));
    });
  });

  group('UsageAnalytics', () {
    const u = UsageAnalytics();

    test('measures idle vs active drain per hour', () {
      final t0 = DateTime(2026, 1, 1, 10);
      final pts = [
        HistoryPoint(time: t0, level: 80, temperatureC: 30, currentMa: -300, charging: false, screenOn: true),
        HistoryPoint(time: t0.add(const Duration(minutes: 30)), level: 75, temperatureC: 30, currentMa: -300, charging: false, screenOn: false),
        HistoryPoint(time: t0.add(const Duration(minutes: 90)), level: 74, temperatureC: 30, currentMa: -50, charging: false, screenOn: false),
      ];
      final d = u.drain(pts);
      expect(d.activePerHour, closeTo(10, 1e-6));
      expect(d.idlePerHour, closeTo(1, 1e-6));
      expect(d.screenOnSinceUnplug, const Duration(minutes: 30));
    });

    test('weekly habits counts full charges and deep discharges', () {
      final now = DateTime.now();
      final points = [
        for (final lvl in [40.0, 4.0, 3.0, 50.0, 5.0, 60.0])
          HistoryPoint(time: now.subtract(const Duration(hours: 5)), level: lvl, temperatureC: 30, currentMa: 0, charging: false, screenOn: true),
      ];
      final r = u.weekly(HistoryBundle(points: points, sessions: [session(now, endLvl: 100), session(now, endLvl: 80)]));
      expect(r.sessions, 2);
      expect(r.fullCharges, 1);
      expect(r.deepDischarges, 2);
      expect(r.summary, contains('Try keeping it between 20% and 80%'));
    });

    test('CSV export includes all three sections', () {
      final csv = u.toCsv(HistoryBundle(sessions: [session(DateTime(2026, 1, 1), label: 'My "fast" brick')]));
      expect(csv, contains('# Charging sessions'));
      expect(csv, contains("\"My 'fast' brick\""));
      expect(csv, contains('# Capacity'));
    });
  });

  group('BatteryMapper', () {
    test('maps a native snapshot map', () {
      final s = BatteryMapper.snapshot({
        'level': 31, 'percent': 31.1, 'status': 'charging', 'charger': 'usb', 'voltageMv': 4100, 'currentMa': 1500.0,
        'temperatureC': 33.5, 'technology': 'Li-poly', 'health': 'good', 'cycleCount': 120, 'timestamp': 0,
        'session': {'id': '1', 'start': 0, 'startLevel': 20.0, 'avgW': 7.5, 'peakW': 9.0, 'maxTemp': 34.0, 'charger': 'usb'},
      });
      expect(s.percent, 31.1);
      expect(s.charger, ChargerType.usb);
      expect(s.isCharging, isTrue);
      expect(s.cycleCount, 120);
      expect(s.session!.avgWatts, 7.5);
    });
  });
}

