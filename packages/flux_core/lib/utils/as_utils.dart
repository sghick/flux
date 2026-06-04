import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// as List<T>?

List<int>? asListInt(dynamic key, {List<int>? defaultKey}) {
  return asList<int>(key, defaultKey: defaultKey);
}

List<bool>? asListBool(dynamic key, {List<bool>? defaultKey}) {
  return asList<bool>(key, defaultKey: defaultKey);
}

List<double>? asListDouble(dynamic key, {List<double>? defaultKey}) {
  return asList<double>(key, defaultKey: defaultKey);
}

List<String>? asListString(dynamic key, {List<String>? defaultKey}) {
  return asList<String>(key, defaultKey: defaultKey);
}

List<T>? asList<T>(dynamic key, {List<T>? defaultKey, T? Function(dynamic)? parser}) {
  if (key is List) {
    try {
      return key.map((e) => asTo<T>(e, parser: parser)!).toList();
    } catch (e) {
      assert(false, e.toString());
    }
  }
  return defaultKey;
}

/// as T?
T? asTo<T>(dynamic key, {T? defaultKey, T? Function(dynamic)? parser}) {
  if (T is int) {
    return asInt(key, defaultKey: defaultKey as int?) as T?;
  }
  if (T is double) {
    return asDouble(key, defaultKey: defaultKey as double?) as T?;
  }
  if (T is bool) {
    return asBool(key, defaultKey: defaultKey as bool?) as T?;
  }
  if (T is String) {
    return asStr(key, defaultKey: defaultKey as String?) as T?;
  }
  if (parser != null) {
    return parser(key);
  }
  return defaultKey;
}

int? asInt(dynamic key, {int? defaultKey}) {
  if (key is String) {
    return int.tryParse(key) ?? double.tryParse(key)?.toInt() ?? defaultKey;
  }
  if (key is bool) {
    return key ? 1 : 0;
  }
  if (key is num) {
    return key.toInt();
  }
  return defaultKey;
}

double? asDouble(dynamic key, {double? defaultKey}) {
  if (key is String) {
    return double.tryParse(key) ?? defaultKey;
  }
  if (key is bool) {
    return key ? 1 : 0;
  }
  if (key is num) {
    return key.toDouble();
  }
  return defaultKey;
}

bool? asBool(dynamic key, {bool? defaultKey}) {
  if (key is String) {
    return bool.tryParse(key) ?? asBool(asDouble(key), defaultKey: defaultKey);
  }
  if (key is bool) {
    return key;
  }
  if (key is num) {
    return key != 0;
  }
  return defaultKey;
}

String? asStr(dynamic key, {String? defaultKey}) {
  if (key is Object) {
    return key.toString();
  }
  if (key is Uint8List) {
    return utf8.decode(key);
  }
  return defaultKey;
}

Map<K, V>? asMap<K, V>(dynamic key, {Map<K, V>? defaultKey}) {
  if (key is Map<K, V>) {
    return key;
  }
  if (key is String) {
    try {
      return json.decode(key);
    } catch (e) {
      return defaultKey;
    }
  }
  if (key is Uint8List) {
    try {
      return json.decode(utf8.decode(key));
    } catch (e) {
      return defaultKey;
    }
  }
  return defaultKey;
}

Map<String, double>? edgeInsetsAsMap(EdgeInsets? edgeInsets) {
  if (edgeInsets == null) return null;
  return {'left': edgeInsets.left, 'top': edgeInsets.top, 'right': edgeInsets.right, 'bottom': edgeInsets.bottom};
}

/// to T
int toInt(dynamic key, {int defaultKey = 0}) {
  return asInt(key, defaultKey: defaultKey) ?? defaultKey;
}

bool toBool(dynamic key, {bool defaultKey = false}) {
  return asBool(key, defaultKey: defaultKey) ?? defaultKey;
}

double toDouble(dynamic key, {double defaultKey = 0}) {
  return asDouble(key, defaultKey: defaultKey) ?? defaultKey;
}

String toStr(dynamic key, {String defaultKey = ''}) {
  return asStr(key, defaultKey: defaultKey) ?? defaultKey;
}

Map<K, V> toMap<K, V>(dynamic key, {Map<K, V> defaultKey = const {}}) {
  return asMap<K, V>(key, defaultKey: defaultKey) ?? defaultKey;
}

Map<String, double> edgeInsetsToMap(EdgeInsets? edgeInsets) {
  return edgeInsetsAsMap(edgeInsets ?? EdgeInsets.zero)!;
}