import 'package:equatable/equatable.dart';

class DeviceInfo extends Equatable {
  final String manufacturer;
  final String model;
  final String androidVersion;
  final int sdkInt;
  final String processor;
  final int cores;
  final String abi;
  final int totalRam;
  final int availRam;
  final int totalStorage;
  final int freeStorage;
  final Duration uptime;
  final String network;

  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.sdkInt,
    required this.processor,
    required this.cores,
    required this.abi,
    required this.totalRam,
    required this.availRam,
    required this.totalStorage,
    required this.freeStorage,
    required this.uptime,
    required this.network,
  });

  double get ramUsedFraction => totalRam == 0 ? 0 : 1 - availRam / totalRam;
  double get storageUsedFraction => totalStorage == 0 ? 0 : 1 - freeStorage / totalStorage;

  @override
  List<Object?> get props => [manufacturer, model, androidVersion, sdkInt, processor, cores, abi, totalRam,
        availRam, totalStorage, freeStorage, uptime, network];
}
