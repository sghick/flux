import 'dart:math';

import 'package:flux_core/utils/pref_utils.dart';

import '../log/logger.dart';

FLXStorage storage = FLXStorage();

enum FLXStorageType { all, local, memory }

class FLXStorage {
  Future<void> init({String? groupId}) async {
    logD('$runtimeType Initializing...');
    memoryStorage.init();
    return localStorage.init(groupId: groupId).then((value) {
      logD('$runtimeType has been initialized');
      return Future.value();
    });
  }

  Future<bool> setObject<T>(String key, T value, {FLXStorageType type = FLXStorageType.all}) {
    switch (type) {
      case FLXStorageType.local:
        {
          return localStorage.setObject(key, value);
        }
      case FLXStorageType.memory:
        {
          memoryStorage.setObject(key, value);
          return Future.value(true);
        }
      default:
        {
          memoryStorage.setObject(key, value);
          return localStorage.setObject(key, value);
        }
    }
  }

  dynamic getObject<T>(String key, {FLXStorageType type = FLXStorageType.all}) {
    switch (type) {
      case FLXStorageType.local:
        {
          return localStorage.getObject(key);
        }
      case FLXStorageType.memory:
        {
          return memoryStorage.getObject(key);
        }
      default:
        {
          var obj = memoryStorage.getObject(key);
          if (obj == null) {
            return localStorage.getObject(key);
          }
          return obj;
        }
    }
  }

  Future<bool> remove(String key, {FLXStorageType type = FLXStorageType.all}) async {
    switch (type) {
      case FLXStorageType.local:
        {
          return localStorage.remove(key);
        }
      case FLXStorageType.memory:
        {
          memoryStorage.remove(key);
          return Future.value(true);
        }
      default:
        {
          memoryStorage.remove(key);
          return localStorage.remove(key);
        }
    }
  }

  Future<bool> clear({FLXStorageType type = FLXStorageType.all}) async {
    switch (type) {
      case FLXStorageType.local:
        {
          return localStorage.clear();
        }
      case FLXStorageType.memory:
        {
          memoryStorage.clear();
          return true;
        }
      default:
        {
          memoryStorage.clear();
          return localStorage.clear();
        }
    }
  }
}

FLXLocalStorage localStorage = FLXLocalStorage._();

class FLXLocalStorage {
  static final FLXLocalStorage _instance = FLXLocalStorage._();

  final FLXSharedPreference _pref = FLXSharedPreference();
  FLXGroupSharedPreference? group;

  FLXLocalStorage._();

  Future<FLXLocalStorage> init({String? groupId}) async {
    await _pref.init();
    if (groupId != null) {
      group = FLXGroupSharedPreference(groupId: groupId);
      await group!.init();
    }
    logD('$runtimeType has been initialized');
    return _instance;
  }

  Future<FLXLocalStorage> get safe async {
    return localStorage.init();
  }

  // ──────────── Set：委托 _pref（null 处理内聚在 FLXSharedPreference）────────────

  Future<bool> setInt(String key, int? value) => _pref.setInt(key, value);

  Future<bool> setDouble(String key, double? value) => _pref.setDouble(key, value);

  Future<bool> setString(String key, String? value) => _pref.setString(key, value);

  Future<bool> setBool(String key, bool? value) => _pref.setBool(key, value);

  Future<bool> setStringList(String key, List<String>? value) => _pref.setStringList(key, value);

  Future<bool> setMap(String key, Map? value) => _pref.setMap(key, value as Map<String, dynamic>?);

  Future<bool> setObject<T>(String key, T? value) => _pref.setObject(key, value);

  // ──────────── Get：同步调用 _pref ────────────

  int? getInt(String key) => _pref.getInt(key);

  double? getDouble(String key) => _pref.getDouble(key);

  String? getString(String key) => _pref.getString(key);

  bool? getBool(String key) => _pref.getBool(key);

  List<String>? getStringList(String key) => _pref.getStringList(key);

  Map<String, dynamic>? getMap(String key) => _pref.getMap(key);

  dynamic getObject<T>(String key) => _pref.getObject(key);

  Set<String> getKeys() => _pref.getKeys();

  bool containsKey(String key) => _pref.containsKey(key);

  // ──────────── 其他操作 ────────────

  Future<bool> remove(String key) => _pref.remove(key);

  Future<bool> clear() => _pref.clear();

  Future<void> reload() => _pref.reload();
}

FLXMemoryStorage memoryStorage = FLXMemoryStorage();

class FLXMemoryStorage {
  static final FLXMemoryStorage _instance = FLXMemoryStorage._();
  final Map<String, dynamic> _obj = {};

  factory FLXMemoryStorage() {
    return _instance;
  }

  FLXMemoryStorage._();

  void init() {
    logD('$runtimeType init success');
  }

  void setObject<T>(String key, T value) {
    _obj[key] = value;
  }

  T? getObject<T>(String key) {
    return _obj[key];
  }

  void remove(String key) {
    _obj.remove(key);
  }

  void clear() {
    _obj.clear();
  }
}

class FLXMemoryCache {
  final Map<String, dynamic> _obj = {};
  final List<String> _priority = [];

  /// 最大缓存个数
  final int limit;

  /// 自动清除缓存时,每次清除的个数
  final int unit;

  FLXMemoryCache({this.limit = 100, this.unit = 10});

  void addAll(Map<String, dynamic> obj) {
    if (limit < _obj.length + obj.length) {
      clearUnit();
    }
    _obj.addAll(obj);
    _priority.addAll(obj.keys);
  }

  void setObject<T>(String key, T value) {
    if (limit < _obj.length + 1) {
      clearUnit();
    }
    _obj[key] = value;

    // 加入优先级列表
    if (!_priority.contains(key)) {
      _priority.add(key);
    }
  }

  T? getObject<T>(String key) {
    // 最近使用将被放在最后
    if (_priority.lastOrNull != key) {
      _priority.remove(key);
      _priority.add(key);
    }
    return _obj[key];
  }

  bool containsKey(String key) => _obj.containsKey(key);

  void remove(String key) {
    _obj.remove(key);
    _priority.remove(key);
  }

  void clear() {
    _obj.clear();
    _priority.clear();
  }

  void clearUnit() {
    var list = _priority.sublist(0, min(_priority.length, unit - 1));
    for (var e in list) {
      _obj.remove(e);
    }
    _priority.removeRange(0, min(_priority.length, unit - 1));
  }
}
