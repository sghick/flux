import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_enums.dart';
import 'api_options.dart';

/// 缓存条目类，封装缓存数据和元数据
class FLXApiCacheEntry<T> {
  /// 缓存数据（原始数据，由序列化器统一处理）
  final T data;

  /// 缓存时间
  final DateTime cacheTime;

  /// 过期时间
  final DateTime? expireTime;

  /// 响应头信息（用于缓存验证）
  final Map<String, dynamic>? headers;

  /// 缓存来源（内存/磁盘）
  final FLXApiCacheLevel? source;

  FLXApiCacheEntry({
    required this.data,
    required this.cacheTime,
    this.expireTime,
    this.headers,
    this.source,
  });

  /// 检查是否过期
  bool get isExpired {
    if (expireTime == null) return false;
    return DateTime.now().isAfter(expireTime!);
  }

  /// 检查是否即将过期（剩余时间小于1分钟）
  bool get isNearExpired {
    if (expireTime == null) return false;
    final remaining = expireTime!.difference(DateTime.now());
    return remaining.inMinutes <= 1;
  }

  /// 转为 JSON（用于磁盘存储）
  Map<String, dynamic> toJson(dynamic data) {
    return {
      'data': data is String ? data : jsonEncode(data),
      'cacheTime': cacheTime.toIso8601String(),
      'expireTime': expireTime?.toIso8601String(),
      'headers': headers,
    };
  }
}

/// 从 JSON 创建缓存条目（用于磁盘读取）
FLXApiCacheEntry<dynamic> createCacheEntryFromJson(Map<String, dynamic> json) {
  return FLXApiCacheEntry<dynamic>(
    data: json['data'] is String ? json['data'] : jsonDecode(json['data']),
    cacheTime: DateTime.parse(json['cacheTime']),
    expireTime: json['expireTime'] != null ? DateTime.parse(json['expireTime']) : null,
    headers: json['headers'] != null ? Map<String, dynamic>.from(json['headers']) : null,
    source: FLXApiCacheLevel.diskOnly,
  );
}

/// 缓存策略配置类
class FLXApiCachePolicy {
  /// 缓存类型
  final FLXApiCacheType type;

  /// 内存缓存有效期（从写入时间开始计算），默认30分钟
  final Duration memoryDuration;

  /// 磁盘缓存有效期（从写入时间开始计算），默认1小时
  final Duration diskDuration;

  /// 缓存最大条目数（内存缓存），默认100
  final int maxMemoryCount;

  /// 缓存最大大小（字节，内存缓存），默认10MB
  final int maxMemorySize;

  /// 缓存存储级别，默认两级缓存（内存+磁盘）
  final FLXApiCacheLevel level;

  /// 自定义缓存键生成器
  final String Function(FLXApiOptions)? keyGenerator;

  const FLXApiCachePolicy({
    this.type = FLXApiCacheType.cacheThenNetwork,
    this.memoryDuration = const Duration(minutes: 30),
    this.diskDuration = const Duration(hours: 1),
    this.maxMemoryCount = 100,
    this.maxMemorySize = 10 * 1024 * 1024, // 10MB
    this.level = FLXApiCacheLevel.memoryAndDisk,
    this.keyGenerator,
  });

  /// 默认配置：两级缓存（内存30分钟 + 磁盘1小时）
  factory FLXApiCachePolicy.defaultCache() {
    return const FLXApiCachePolicy();
  }

  /// 仅内存缓存（无磁盘持久化）
  factory FLXApiCachePolicy.memoryOnly({
    Duration duration = const Duration(minutes: 30),
    int maxCount = 100,
  }) {
    return FLXApiCachePolicy(
      type: FLXApiCacheType.cacheFirst,
      memoryDuration: duration,
      maxMemoryCount: maxCount,
      level: FLXApiCacheLevel.memoryOnly,
    );
  }

  /// 是否启用内存缓存
  bool get hasMemoryCache =>
      level == FLXApiCacheLevel.memoryOnly || level == FLXApiCacheLevel.memoryAndDisk;

  /// 是否启用磁盘缓存
  bool get hasDiskCache =>
      level == FLXApiCacheLevel.diskOnly || level == FLXApiCacheLevel.memoryAndDisk;

  /// 计算内存缓存过期时间
  DateTime? get memoryExpireTime =>
      hasMemoryCache ? DateTime.now().add(memoryDuration) : null;

  /// 计算磁盘缓存过期时间
  DateTime? get diskExpireTime =>
      hasDiskCache ? DateTime.now().add(diskDuration) : null;
}

/// 缓存管理器（单例）
class FLXApiCache {
  static final FLXApiCache _instance = FLXApiCache._internal();
  factory FLXApiCache() => _instance;
  FLXApiCache._internal();

  // 内存缓存：LRU LinkedHashMap
  final LinkedHashMap<String, FLXApiCacheEntry<dynamic>> _memoryCache =
      LinkedHashMap();

  // 内存缓存统计
  int _memoryCacheCount = 0;
  int _memoryCacheSize = 0;
  int _memoryHitCount = 0;
  int _diskHitCount = 0;

  // 请求去重
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  // SharedPreferences 实例
  SharedPreferences? _prefs;
  static const String _diskCachePrefix = 'flx_api_cache_';

  /// 初始化 SharedPreferences
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 从缓存读取
  /// 读取顺序：内存缓存 -> 磁盘缓存
  /// 若从磁盘读取，会自动回填内存缓存
  Future<T?> get<T>(String key, {FLXApiCachePolicy? policy}) async {
    // 1. 先检查内存缓存
    if (policy?.hasMemoryCache ?? true) {
      final entry = _memoryCache[key];
      if (entry != null && !entry.isExpired) {
        _memoryHitCount++;
        // 移动到末尾（LRU 更新）
        _memoryCache.remove(key);
        _memoryCache[key] = entry;
        return entry.data as T;
      } else if (entry != null) {
        // 已过期，删除
        _memoryCache.remove(key);
        _updateMemoryStats();
      }
    }

    // 2. 检查磁盘缓存
    if (policy?.hasDiskCache ?? true) {
      await _ensureInitialized();
      final jsonStr = _prefs?.getString('$_diskCachePrefix$key');
      if (jsonStr != null) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final entry = createCacheEntryFromJson(json);
          if (!entry.isExpired) {
            _diskHitCount++;
            // 回填内存缓存
            if (policy?.hasMemoryCache ?? true) {
              await _setMemoryCache(
                key,
                entry.data,
                expireTime: entry.expireTime,
              );
            }
            return entry.data as T;
          } else {
            // 已过期，删除
            await _prefs?.remove('$_diskCachePrefix$key');
          }
        } catch (e) {
          // 解析失败，删除缓存
          await _prefs?.remove('$_diskCachePrefix$key');
        }
      }
    }

    return null;
  }

  /// 写入缓存
  /// 写入顺序：内存缓存 -> 磁盘缓存（根据 level 配置）
  Future<void> set<T>(
    String key,
    T data, {
    FLXApiCachePolicy? policy,
    Map<String, dynamic>? headers,
  }) async {
    final now = DateTime.now();

    // 1. 写入内存缓存
    if (policy?.hasMemoryCache ?? true) {
      await _setMemoryCache(
        key,
        data,
        headers: headers,
        expireTime: policy?.memoryExpireTime,
      );
    }

    // 2. 写入磁盘缓存
    if (policy?.hasDiskCache ?? true) {
      await _ensureInitialized();
      final entry = FLXApiCacheEntry<dynamic>(
        data: data,
        cacheTime: now,
        expireTime: policy?.diskExpireTime,
        headers: headers,
        source: FLXApiCacheLevel.diskOnly,
      );
      final jsonStr = jsonEncode(entry.toJson(data));
      await _prefs?.setString('$_diskCachePrefix$key', jsonStr);
    }
  }

  /// 写入内存缓存
  Future<void> _setMemoryCache(
    String key,
    dynamic data, {
    Map<String, dynamic>? headers,
    DateTime? expireTime,
  }) async {
    // LRU 淘汰：如果达到容量上限，先删除最久未使用的
    while (_memoryCacheCount >= 100) {
      // 删除最旧的条目
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
      _updateMemoryStats();
    }

    _memoryCache[key] = FLXApiCacheEntry<dynamic>(
      data: data,
      cacheTime: DateTime.now(),
      expireTime: expireTime,
      headers: headers,
      source: FLXApiCacheLevel.memoryOnly,
    );
    _updateMemoryStats();
  }

  /// 删除缓存（同时删除内存和磁盘）
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    _updateMemoryStats();
    await _ensureInitialized();
    await _prefs?.remove('$_diskCachePrefix$key');
  }

  /// 清空所有缓存（内存和磁盘）
  Future<void> clear() async {
    _memoryCache.clear();
    _updateMemoryStats();
    await _ensureInitialized();
    final keys = _prefs?.getKeys().where((k) => k.startsWith(_diskCachePrefix));
    if (keys != null) {
      for (final key in keys) {
        await _prefs?.remove(key);
      }
    }
    _memoryHitCount = 0;
    _diskHitCount = 0;
  }

  /// 清理过期缓存（内存和磁盘）
  Future<void> clearExpired() async {
    // 清理内存缓存
    final now = DateTime.now();
    _memoryCache.removeWhere((key, entry) {
      if (entry.expireTime != null && entry.expireTime!.isBefore(now)) {
        return true;
      }
      return false;
    });
    _updateMemoryStats();

    // 清理磁盘缓存
    await _ensureInitialized();
    final keys = _prefs?.getKeys().where((k) => k.startsWith(_diskCachePrefix));
    if (keys != null) {
      for (final key in keys) {
        final jsonStr = _prefs?.getString(key);
        if (jsonStr != null) {
          try {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            final expireTimeStr = json['expireTime'] as String?;
            if (expireTimeStr != null) {
              final expireTime = DateTime.parse(expireTimeStr);
              if (expireTime.isBefore(now)) {
                await _prefs?.remove(key);
              }
            }
          } catch (e) {
            // 解析失败，删除缓存
            await _prefs?.remove(key);
          }
        }
      }
    }
  }

  /// 生成缓存键
  String generateKey(FLXApiOptions options) {
    final buffer = StringBuffer();
    buffer.write(options.method.value);
    buffer.write('_');
    buffer.write(options.fullUrl);
    buffer.write('_');
    buffer.write(options.params?.toString() ?? '');
    buffer.write('_');
    buffer.write(options.data?.toString() ?? '');
    return md5.convert(utf8.encode(buffer.toString())).toString();
  }

  /// 检查缓存是否存在（仅检查内存）
  bool exists(String key) {
    final entry = _memoryCache[key];
    return entry != null && !entry.isExpired;
  }

  /// 获取内存缓存命中数
  int get memoryHitCount => _memoryHitCount;

  /// 获取磁盘缓存命中数
  int get diskHitCount => _diskHitCount;

  /// 获取内存缓存条目数
  int get memoryCount => _memoryCacheCount;

  /// 获取磁盘缓存条目数
  Future<int> getDiskCount() async {
    await _ensureInitialized();
    return _prefs?.getKeys().where((k) => k.startsWith(_diskCachePrefix)).length ?? 0;
  }

  /// 更新内存缓存统计
  void _updateMemoryStats() {
    _memoryCacheCount = _memoryCache.length;
    // 简化：每个条目估算 1KB
    _memoryCacheSize = _memoryCacheCount * 1024;
  }

  /// 获取去重的请求
  Future<T?> getOrCreate<T>(String key, Future<T?> Function() factory) async {
    if (_pendingRequests.containsKey(key)) {
      final completer = _pendingRequests[key]!;
      return await completer.future as T?;
    }

    final completer = Completer<T?>();
    _pendingRequests[key] = completer;

    try {
      final result = await factory();
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingRequests.remove(key);
    }
  }
}
