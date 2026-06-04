import 'dart:convert';
import 'dart:math';
// import 'package:group_shared_preferences/group_shared_preferences.dart';
import 'package:flux_core/utils/pref_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  SharedPreferences get _sharedPreferences => sharedPref;
  // late GroupSharedPreferences group;

  FLXLocalStorage._();

  Future<FLXLocalStorage> init({String? groupId}) async {
    if (groupId != null) {
      // group = GroupSharedPreferences(groupId);
    }
    return initSharedPref()
        .then((value) {
          logD('$runtimeType has been initialized');
          return _instance;
        })
        .catchError((e) {
          logE('$runtimeType initialized failed:$e');
          return e;
        });
  }

  Future<FLXLocalStorage> get safe async {
    return localStorage.init();
  }

  Future<bool> setInt(String key, int? value) {
    if (value != null) {
      return _sharedPreferences.setInt(key, value);
    } else {
      return _sharedPreferences.remove(key);
    }
  }

  Future<bool> setDouble(String key, double? value) {
    if (value != null) {
      return _sharedPreferences.setDouble(key, value);
    } else {
      return _sharedPreferences.remove(key);
    }
  }

  Future<bool> setString(String key, String? value) {
    if (value != null) {
      return _sharedPreferences.setString(key, value);
    } else {
      return _sharedPreferences.remove(key);
    }
  }

  Future<bool> setBool(String key, bool? value) {
    if (value != null) {
      return _sharedPreferences.setBool(key, value);
    } else {
      return _sharedPreferences.remove(key);
    }
  }

  Future<bool> setStringList(String key, List<String>? value) {
    if (value != null) {
      return _sharedPreferences.setStringList(key, value);
    } else {
      return _sharedPreferences.remove(key);
    }
  }

  Future<bool> setMap(String key, Map? value) {
    if (value != null) {
      return _sharedPreferences.setString(key, json.encode(value));
    } else {
      return _sharedPreferences.remove(key);
    }
  }

  /// 通用设置持久化数据
  Future<bool> setObject<T>(String key, T? value) {
    if (value != null) {
      String type = value.runtimeType.toString();
      switch (type) {
        case "String":
          return setString(key, value as String);
        case "int":
          return setInt(key, value as int);
        case "bool":
          return setBool(key, value as bool);
        case "double":
          return setDouble(key, value as double);
        case "List<String>":
          return setStringList(key, value as List<String>);
        case "_InternalLinkedHashMap<String, String>":
          return setMap(key, value as Map);
        default:
          throw Exception("Unsupported type: ${value.runtimeType}");
      }
    } else {
      return _sharedPreferences.remove(key);
    }
  }

  int? getInt(String key) {
    return _sharedPreferences.getInt(key);
  }

  double? getDouble(String key) {
    return _sharedPreferences.getDouble(key);
  }

  String? getString(String key) {
    return _sharedPreferences.getString(key);
  }

  bool? getBool(String key) {
    return _sharedPreferences.getBool(key);
  }

  List<String>? getStringList(String key) {
    return _sharedPreferences.getStringList(key);
  }

  Map<String, dynamic>? getMap(String key) {
    String jsonStr = _sharedPreferences.getString(key) ?? "";
    return jsonStr.isNotEmpty ? json.decode(jsonStr) : null;
  }

  dynamic getObject<T>(String key) {
    return _sharedPreferences.get(key);
  }

  Set<String> getKeys() {
    return _sharedPreferences.getKeys();
  }

  bool containsKey(String key) {
    return _sharedPreferences.containsKey(key);
  }

  Future<bool> remove(String key) async {
    return _sharedPreferences.remove(key);
  }

  Future<bool> clear() async {
    return _sharedPreferences.clear();
  }

  Future<void> reload() async {
    return _sharedPreferences.reload();
  }
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

class CBMemoryCache {
  final Map<String, dynamic> _obj = {};
  final List<String> _priority = [];

  /// 最大缓存个数
  final int limit;

  /// 自动清除缓存时,每次清除的个数
  final int unit;

  CBMemoryCache({this.limit = 100, this.unit = 10});

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
