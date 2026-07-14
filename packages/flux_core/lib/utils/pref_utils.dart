import 'dart:convert';

import 'package:shared_preference_app_group/shared_preference_app_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 同步读 + 异步写的统一抽象接口（仅 [FLXSharedPreference] 实现）
abstract class FLXSharedPreferenceInterface {
  Future<void> init();

  // 写 —— 异步
  Future<bool> setInt(String key, int? value);
  Future<bool> setDouble(String key, double? value);
  Future<bool> setString(String key, String? value);
  Future<bool> setBool(String key, bool? value);
  Future<bool> setStringList(String key, List<String>? value);
  Future<bool> setMap(String key, Map<String, dynamic>? value);
  Future<bool> setObject(String key, dynamic value);

  // 读 —— 同步（SharedPreferences 内存缓存支持）
  int? getInt(String key);
  double? getDouble(String key);
  String? getString(String key);
  bool? getBool(String key);
  List<String>? getStringList(String key);
  Map<String, dynamic>? getMap(String key);
  dynamic getObject(String key);

  Future<bool> remove(String key);
  Future<bool> clear();
  Set<String> getKeys();
  bool containsKey(String key);
  Future<void> reload();
}

/// 封装 [SharedPreferences] 插件，实现 [FLXSharedPreferenceInterface]
class FLXSharedPreference extends FLXSharedPreferenceInterface {
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

  @override
  Future<bool> clear() => _pref.clear();

  @override
  Set<String> getKeys() => _pref.getKeys();

  @override
  bool containsKey(String key) => _pref.containsKey(key);

  @override
  Future<void> reload() => _pref.reload();
}

/// 封装 [SharedPreferenceAppGroup] 插件，用于 iOS/macOS App Group 间的数据共享
///
/// 注意：不实现 [FLXSharedPreferenceInterface]，因为 App Group 底层读写均为异步，
/// 与接口的同步读签名不兼容。请直接通过 [FLXLocalStorage.group] 使用其异步 API。
class FLXGroupSharedPreference {
  final String groupId;
  bool _initialized = false;

  FLXGroupSharedPreference({required this.groupId});

  Future<void> init() async {
    if (!_initialized) {
      await SharedPreferenceAppGroup.setAppGroup(groupId);
      _initialized = true;
    }
  }

  Future<bool> setInt(String key, int? value) async {
    if (value != null) {
      await SharedPreferenceAppGroup.setInt(key, value);
      return true;
    }
    return remove(key);
  }

  Future<bool> setDouble(String key, double? value) async {
    if (value != null) {
      await SharedPreferenceAppGroup.setDouble(key, value);
      return true;
    }
    return remove(key);
  }

  Future<bool> setString(String key, String? value) async {
    if (value != null) {
      await SharedPreferenceAppGroup.setString(key, value);
      return true;
    }
    return remove(key);
  }

  Future<bool> setBool(String key, bool? value) async {
    if (value != null) {
      await SharedPreferenceAppGroup.setBool(key, value);
      return true;
    }
    return remove(key);
  }

  Future<bool> setStringList(String key, List<String>? value) async {
    if (value != null) {
      await SharedPreferenceAppGroup.setStringList(key, value);
      return true;
    }
    return remove(key);
  }

  Future<bool> setMap(String key, Map<String, dynamic>? value) async {
    if (value != null) {
      await SharedPreferenceAppGroup.setString(key, json.encode(value));
      return true;
    }
    return remove(key);
  }

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

  Future<int?> getInt(String key) => SharedPreferenceAppGroup.getInt(key);

  Future<double?> getDouble(String key) => SharedPreferenceAppGroup.getDouble(key);

  Future<String?> getString(String key) => SharedPreferenceAppGroup.getString(key);

  Future<bool?> getBool(String key) => SharedPreferenceAppGroup.getBool(key);

  Future<List<String>?> getStringList(String key) => SharedPreferenceAppGroup.getStringList(key);

  Future<Map<String, dynamic>?> getMap(String key) async {
    final str = await SharedPreferenceAppGroup.getString(key);
    return str != null && str.isNotEmpty ? json.decode(str) as Map<String, dynamic> : null;
  }

  Future<dynamic> getObject(String key) async {
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

  Future<bool> remove(String key) async {
    await SharedPreferenceAppGroup.setString(key, '');
    return true;
  }

  // Future<bool> clear() => throw UnimplementedError('App Group 不支持 clear 操作');
  //
  // Future<Set<String>> getKeys() => throw UnimplementedError('App Group 不支持 getKeys 操作');

  Future<bool> containsKey(String key) async {
    final val = await SharedPreferenceAppGroup.getString(key);
    return val != null;
  }

  Future<void> reload() => Future.value();
}
