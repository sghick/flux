import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flux_core/log/logger.dart';

class FLXDeviceInfoX {
  static late PackageInfo? _finalPackageInfo;
  static late BaseDeviceInfo? _finalDeviceInfo;
  static late String? _finalAndroidId;

  static PackageInfo get _packageInfo =>
      _finalPackageInfo ??
      (throw Exception('Needs call FLXDeviceInfoX.init to initialise'));

  static dynamic get _deviceInfo =>
      _finalDeviceInfo ??
      (throw Exception('Needs call FLXDeviceInfoX.init to initialise'));

  static String get _androidId =>
      _finalAndroidId ??
      (throw Exception('Needs call FLXDeviceInfoX.init to initialise'));

  Future<void> init() async {
    _finalPackageInfo = await PackageInfo.fromPlatform();
    _finalDeviceInfo = await DeviceInfoPlugin().deviceInfo;
    if (Platform.isAndroid) {
      _finalAndroidId = await const AndroidId().getId();
    }
    logD('$runtimeType has been initialized');
  }

  static String get buildNo => _packageInfo.buildNumber;

  static String get appVersion => _packageInfo.version;

  static String get packageName => _packageInfo.packageName;

  static String get uuid {
    if (Platform.isAndroid) {
      return _androidId;
    } else if (_deviceInfo is IosDeviceInfo) {
      return _deviceInfo.identifierForVendor;
    }
    return '';
  }
}
