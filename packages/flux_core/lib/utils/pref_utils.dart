import 'dart:convert';

import 'package:shared_preference_app_group/shared_preference_app_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 异步读写的统一抽象接口
abstract class FLXSharedPreferenceInterface {
  Future<void> init();

  Future<bool> setInt(String key, int? value);
  Future<bool> setDouble(String key, double? value);
  Future<bool> setString(String key, String? value);
  Future<bool> setBool(String key, bool? value);
  Future<bool> setStringList(String key, List<String>? value);
  Future<bool> setMap(String key, Map<String, dynamic>? value);
  Future<bool> setObject(String key, dynamic value);

  Future<int?> getAsyncInt(String key);
  Future<double?> getAsyncDouble(String key);
  Future<String?> getAsyncString(String key);
  Future<bool?> getAsyncBool(String key);
  Future<List<String>?> getAsyncStringList(String key);
  Future<Map<String, dynamic>?> getAsyncMap(String key);
  Future<dynamic> getAsyncObject(String key);

  Future<bool> remove(String key);
  Future<bool> containsKey(String key);
  Future<void> reload();
}

abstract class FLXSharedPreferenceSyncGetterInterface {
  int? getInt(String key);
  double? getDouble(String key);
  String? getString(String key);
  bool? getBool(String key);
  List<String>? getStringList(String key);
  Map<String, dynamic>? getMap(String key);
  dynamic getObject(String key);
}

/// 封装 [SharedPreferences] 插件
class FLXSharedPreference extends FLXSharedPreferenceInterface implements FLXSharedPreferenceSyncGetterInterface {
  late SharedPreferences _pref;

  @override
  Future<void> init() async {
    _pref = await SharedPreferences.getInstance();
  }

  @override
  Future<bool> setInt(String key, int? value) =>
      value != null ? _pref.setInt(key, value) : _pref.remove(key);

  @override
  Future<bool> setDouble(String key, double? value) =>
      value != null ? _pref.setDouble(key, value) : _pref.remove(key);

  @override
  Future<bool> setString(String key, String? value) =>
      value != null ? _pref.setString(key, value) : _pref.remove(key);

  @override
  Future<bool> setBool(String key, bool? value) =>
      value != null ? _pref.setBool(key, value) : _pref.remove(key);

  @override
  Future<bool> setStringList(String key, List<String>? value) =>
      value != null ? _pref.setStringList(key, value) : _pref.remove(key);

  @override
  Future<bool> setMap(String key, Map<String, dynamic>? value) =>
      value != null ? _pref.setString(key, json.encode(value)) : _pref.remove(key);

  @override
  Future<bool> setObject(String key, dynamic value) async {
    if (value == null) return remove(key);
    final type = value.runtimeType.toString();
    switch (type) {
      case 'String':
        return setString(key, value as String);
      case 'int':
        return setInt(key, value as int);
      case 'bool':
        return setBool(key, value as bool);
      case 'double':
        return setDouble(key, value as double);
      case 'List<String>':
        return setStringList(key, value as List<String>);
      default:
        if (value is Map) return setMap(key, value as Map<String, dynamic>);
        throw Exception('Unsupported type: $type');
    }
  }

  @override
  Future<int?> getAsyncInt(String key) => Future.value(_pref.getInt(key));

  @override
  Future<double?> getAsyncDouble(String key) => Future.value(_pref.getDouble(key));

  @override
  Future<String?> getAsyncString(String key) => Future.value(_pref.getString(key));

  @override
  Future<bool?> getAsyncBool(String key) => Future.value(_pref.getBool(key));

  @override
  Future<List<String>?> getAsyncStringList(String key) => Future.value(_pref.getStringList(key));

  @override
  Future<Map<String, dynamic>?> getAsyncMap(String key) async {
    final str = _pref.getString(key);
    return str != null && str.isNotEmpty ? json.decode(str) as Map<String, dynamic> : null;
  }

  @override
  Future<dynamic> getAsyncObject(String key) => Future.value(_pref.get(key));

  @override
  int? getInt(String key) => _pref.getInt(key);

  @override
  double? getDouble(String key) => _pref.getDouble(key);

  @override
  String? getString(String key) => _pref.getString(key);

  @override
  bool? getBool(String key) => _pref.getBool(key);

  @override
  List<String>? getStringList(String key) => _pref.getStringList(key);

  @override
  Map<String, dynamic>? getMap(String key) {
    final str = _pref.getString(key);
    return str != null && str.isNotEmpty ? json.decode(str) as Map<String, dynamic> : null;
  }

  @override
  dynamic getObject(String key) => _pref.get(key);

  @override
  Future<bool> remove(String key) => _pref.remove(key);

  Future<bool> clear() => _pref.clear();

  Future<Set<String>> getKeys() => Future.value(_pref.getKeys());

  @override
  Future<bool> containsKey(String key) => Future.value(_pref.containsKey(key));

  @override
  Future<void> reload() => _pref.reload();
}

/// 封装 [SharedPreferenceAppGroup] 插件，用于 iOS/macOS App Group 间的数据共享
class FLXGroupSharedPreference extends FLXSharedPreferenceInterface {
  bool _initialized = false;

  FLXGroupSharedPreference();

  Future<void> init({String? groupId}) async {
    if (groupId == null) return;
    if (!_initialized) {
      await SharedPreferenceAppGroup.setAppGroup(groupId);
      _initialized = true;
    }
  }

  bool get isInitialized => _initialized;

  @override
  Future<bool> setInt(String key, int? value) async {
    if (!_initialized) return false;
    if (value != null) {
      await SharedPreferenceAppGroup.setInt(key, value);
      return true;
    }
    return remove(key);
  }

  @override
  Future<bool> setDouble(String key, double? value) async {
    if (!_initialized) return false;
    if (value != null) {
      await SharedPreferenceAppGroup.setDouble(key, value);
      return true;
    }
    return remove(key);
  }

  @override
  Future<bool> setString(String key, String? value) async {
    if (!_initialized) return false;
    if (value != null) {
      await SharedPreferenceAppGroup.setString(key, value);
      return true;
    }
    return remove(key);
  }

  @override
  Future<bool> setBool(String key, bool? value) async {
    if (!_initialized) return false;
    if (value != null) {
      await SharedPreferenceAppGroup.setBool(key, value);
      return true;
    }
    return remove(key);
  }

  @override
  Future<bool> setStringList(String key, List<String>? value) async {
    if (!_initialized) return false;
    if (value != null) {
      await SharedPreferenceAppGroup.setStringList(key, value);
      return true;
    }
    return remove(key);
  }

  @override
  Future<bool> setMap(String key, Map<String, dynamic>? value) async {
    if (!_initialized) return false;
    if (value != null) {
      await SharedPreferenceAppGroup.setString(key, json.encode(value));
      return true;
    }
    return remove(key);
  }

  @override
  Future<bool> setObject(String key, dynamic value) async {
    if (!_initialized) return false;
    if (value == null) return remove(key);
    final type = value.runtimeType.toString();
    switch (type) {
      case 'String':
        return setString(key, value as String);
      case 'int':
        return setInt(key, value as int);
      case 'bool':
        return setBool(key, value as bool);
      case 'double':
        return setDouble(key, value as double);
      case 'List<String>':
        return setStringList(key, value as List<String>);
      default:
        if (value is Map) return setMap(key, value as Map<String, dynamic>);
        throw Exception('Unsupported type: $type');
    }
  }

  @override
  Future<int?> getAsyncInt(String key) =>
      _initialized ? SharedPreferenceAppGroup.getInt(key) : Future.value(null);

  @override
  Future<double?> getAsyncDouble(String key) =>
      _initialized ? SharedPreferenceAppGroup.getDouble(key) : Future.value(null);

  @override
  Future<String?> getAsyncString(String key) =>
      _initialized ? SharedPreferenceAppGroup.getString(key) : Future.value(null);

  @override
  Future<bool?> getAsyncBool(String key) =>
      _initialized ? SharedPreferenceAppGroup.getBool(key) : Future.value(null);

  @override
  Future<List<String>?> getAsyncStringList(String key) =>
      _initialized ? SharedPreferenceAppGroup.getStringList(key) : Future.value(null);

  @override
  Future<Map<String, dynamic>?> getAsyncMap(String key) async {
    if (!_initialized) return null;
    final str = await SharedPreferenceAppGroup.getString(key);
    return str != null && str.isNotEmpty ? json.decode(str) as Map<String, dynamic> : null;
  }

  @override
  Future<dynamic> getAsyncObject(String key) async {
    if (!_initialized) return null;
    dynamic val;
    val = await SharedPreferenceAppGroup.getString(key);
    if (val != null) return val;
    val = await SharedPreferenceAppGroup.getInt(key);
    if (val != null) return val;
    val = await SharedPreferenceAppGroup.getBool(key);
    if (val != null) return val;
    val = await SharedPreferenceAppGroup.getDouble(key);
    if (val != null) return val;
    val = await SharedPreferenceAppGroup.getStringList(key);
    return val;
  }

  @override
  Future<bool> remove(String key) async {
    if (!_initialized) return false;
    await SharedPreferenceAppGroup.setString(key, '');
    return true;
  }

  @override
  Future<bool> containsKey(String key) async {
    if (!_initialized) return false;
    final val = await SharedPreferenceAppGroup.getString(key);
    return val != null;
  }

  @override
  Future<void> reload() => Future.value();
}
