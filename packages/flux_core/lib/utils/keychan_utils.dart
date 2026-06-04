import 'package:flux_core/utils/storage_utils.dart';
import 'package:flutter_keychain_plus/flutter_keychain_plus.dart';
import 'package:uuid/uuid.dart';

import '../log/logger.dart';

final FLXKeychainService keychainService = FLXKeychainService();

class FLXKeychainService {
  static const String keychainUuid = 'DE4AppInfo.keychain.UUID';

  late final String uuid;

  Future<String> init() {
    return _init().then((value) {
      uuid = value;
      logD('$runtimeType has been initialized');
      logD('keychain uuid: $value');
      return value;
    });
  }

  Future<String> _init() {
    return FlutterKeychainPlus.get(key: keychainUuid).then((value) {
      if (value == null) {
        final uuid = Uuid().v4().toString();
        localStorage.setString("deviceId", uuid);
        FlutterKeychainPlus.put(key: keychainUuid, value: uuid);
        return uuid;
      }
      return value;
    });
  }
}
