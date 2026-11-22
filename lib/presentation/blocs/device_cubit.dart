import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/device_info.dart';
import '../../domain/usecases/usecases.dart';

class DeviceCubit extends Cubit<DeviceInfo?> {
  final GetDeviceInfo _get;
  Timer? _timer;

  DeviceCubit(this._get) : super(null);

  Future<void> refresh() async {
    try {
      emit(await _get());
    } catch (_) {}
  }

  void startPolling() {
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  void stopPolling() => _timer?.cancel();

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
