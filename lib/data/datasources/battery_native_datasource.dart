import 'package:flutter/services.dart';

/// Thin wrapper over the Kotlin MethodChannel / EventChannels.
class BatteryNativeDataSource {
  static const _methods = MethodChannel('voltpulse/methods');
  static const _battery = EventChannel('voltpulse/battery');
  static const _power = EventChannel('voltpulse/power');

  Stream<Map<Object?, Object?>> batteryStream() =>
      _battery.receiveBroadcastStream().map((e) => e as Map<Object?, Object?>);

  Stream<Map<Object?, Object?>> powerStream() =>
      _power.receiveBroadcastStream().map((e) => e as Map<Object?, Object?>);

  Future<Map<Object?, Object?>?> snapshot() => _methods.invokeMapMethod<Object?, Object?>('getSnapshot');

  Future<List<Map<Object?, Object?>>> _list(String method) async {
    final raw = await _methods.invokeListMethod<Object?>(method) ?? const [];
    return raw.cast<Map<Object?, Object?>>();
  }

  Future<List<Map<Object?, Object?>>> history() => _list('getHistory');
  Future<List<Map<Object?, Object?>>> sessions() => _list('getSessions');
  Future<List<Map<Object?, Object?>>> capacity() => _list('getCapacitySamples');

  Future<void> labelSession(String id, String? label) =>
      _methods.invokeMethod('labelSession', {'id': id, 'label': label});
  Future<void> clearHistory() => _methods.invokeMethod('clearHistory');
  Future<void> updateSettings(Map<String, Object?> s) => _methods.invokeMethod('updateSettings', s);
  Future<bool> requestNotificationPermission() async =>
      await _methods.invokeMethod<bool>('requestNotificationPermission') ?? false;
  Future<void> playFeedback(bool connected) => _methods.invokeMethod('playFeedback', {'connected': connected});
  Future<void> stopAlarm() => _methods.invokeMethod('stopAlarm');
  Future<void> setKeepScreenOn(bool on, double? brightness) =>
      _methods.invokeMethod('setKeepScreenOn', {'on': on, 'brightness': brightness});
  Future<Map<Object?, Object?>?> deviceInfo() => _methods.invokeMapMethod<Object?, Object?>('getDeviceInfo');
  Future<String> saveCsv(String name, String content, bool share) async =>
      await _methods.invokeMethod<String>('saveCsv', {'fileName': name, 'content': content, 'share': share}) ?? '';
  Future<void> shareImage(Uint8List png, String name) =>
      _methods.invokeMethod('shareImage', {'png': png, 'fileName': name});
}
