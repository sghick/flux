# 网络请求缓存系统设计文档

## 1. 功能概述

为 flux_core 网络层设计一套可配置的缓存系统，通过 `FLXApiCachePolicy` 控制缓存行为，支持多种缓存策略，提升应用性能和用户体验。

### 1.1 核心特性

- **API 级别独立配置**：每个 API 实例都可以独立设置不同的缓存策略和配置
- **多种缓存策略**：支持 6 种缓存策略，满足不同业务场景需求
- **两级缓存架构**：内存缓存（LRU）+ 磁盘缓存（key-value），默认启用两级缓存
- **灵活的缓存配置**：可配置缓存时效、容量、键生成规则、缓存级别等
- **离线支持**：磁盘缓存支持应用重启后数据持久化
- **原始数据存储**：缓存 value 保存后端返回的原始响应数据，不做额外序列化转换

## 2. 设计方案

### 2.1 架构设计

缓存系统由以下核心组件组成：

1. **FLXApiCacheType** - 缓存类型枚举，定义不同的缓存行为
2. **FLXApiCachePolicy** - 缓存策略配置类，包含缓存时效、容量、键生成等配置
3. **FLXApiCache** - 缓存管理器，负责缓存读写、过期清理
4. **FLXApiCacheEntry** - 缓存条目类，封装缓存数据和元数据

### 2.2 缓存类型枚举 (FLXApiCacheType)

```dart
enum FLXApiCacheType {
  /// 不使用缓存，每次都发起网络请求
  noCache,

  /// 优先使用缓存，如果没有缓存或缓存过期，发起网络请求
  cacheFirst,

  /// 同时返回缓存和网络请求结果（缓存立即返回，网络请求异步更新缓存）
  cacheThenNetwork,

  /// 优先使用网络请求，失败时使用缓存
  networkThenCache,

  /// 仅网络请求，成功后更新缓存
  networkOnlyCache,

  /// 仅使用缓存，不发起网络请求
  cacheOnly,
}
```

### 2.3 缓存策略配置 (FLXApiCachePolicy)

```dart
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

  /// 磁盘缓存路径（可选，默认使用 shared_preferences）
  final String? diskCacheDir;

  const FLXApiCachePolicy({
    this.type = FLXApiCacheType.cacheThenNetwork,
    this.memoryDuration = const Duration(minutes: 30),
    this.diskDuration = const Duration(hours: 1),
    this.maxMemoryCount = 100,
    this.maxMemorySize = 10 * 1024 * 1024, // 10MB
    this.level = FLXApiCacheLevel.memoryAndDisk,
    this.keyGenerator,
    this.diskCacheDir,
  });

  /// 默认配置：两级缓存（内存30分钟 + 磁盘1小时）
  factory FLXApiCachePolicy.defaultCache() {
    return const FLXApiCachePolicy(
      type: FLXApiCacheType.cacheFirst,
      memoryDuration: Duration(minutes: 30),
      diskDuration: Duration(hours: 1),
    );
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
}

/// 缓存存储级别
enum FLXApiCacheLevel {
  /// 仅内存缓存（重启后丢失）
  memoryOnly,

  /// 仅磁盘缓存
  diskOnly,

  /// 两级缓存（默认，内存优先，磁盘兜底）
  memoryAndDisk,
}
```

### 2.4 缓存条目 (FLXApiCacheEntry)

```dart
class FLXApiCacheEntry<T> {
  /// 缓存数据
  final T data;

  /// 缓存时间
  final DateTime cacheTime;

  /// 过期时间
  final DateTime? expireTime;

  /// 响应头信息（用于缓存验证）
  final Map<String, dynamic>? headers;

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
}
```

### 2.5 缓存管理器 (FLXApiCache)

```dart
class FLXApiCache {
  static final FLXApiCache _instance = FLXApiCache._internal();
  factory FLXApiCache() => _instance;

  // 内存缓存：LRU Map
  final LinkedHashMap<String, FLXApiCacheEntry<dynamic>> _memoryCache = LinkedHashMap();
  int _memoryCacheCount = 0;
  int _memoryCacheSize = 0;

  /// 从缓存读取（返回原始数据，由 FLXApiOptions 的序列化器统一处理序列化/反序列化）
  /// 读取顺序：内存缓存 -> 磁盘缓存
  /// 若从磁盘读取，会自动回填内存缓存
  Future<T?> get<T>(String key) async;

  /// 写入缓存（存储原始数据，由 FLXApiOptions 的序列化器统一处理序列化/反序列化）
  /// 写入顺序：内存缓存 -> 磁盘缓存（根据 level 配置）
  Future<void> set<T>(
    String key,
    T data, {
    FLXApiCachePolicy? policy,
    Map<String, dynamic>? headers,
  }) async;

  /// 删除缓存（同时删除内存和磁盘）
  Future<void> remove(String key) async;

  /// 清空所有缓存（内存和磁盘）
  Future<void> clear() async;

  /// 清理过期缓存（内存和磁盘）
  Future<void> clearExpired() async;

  /// 生成缓存键
  String generateKey(FLXApiOptions options);

  /// 检查缓存是否存在（仅检查内存）
  Future<bool> exists(String key) async;

  /// 获取内存缓存命中数
  int get memoryHitCount;

  /// 获取磁盘缓存命中数
  int get diskHitCount;
}
```

## 3. 集成方案

### 3.1 FLXApiOptions 扩展

在 `/Users/tinswin/dzw/tinswin-flutter/flux/packages/flux_core/lib/net/api_options.dart` 中添加：

```dart
class FLXApiOptions {
  // ... 现有字段 ...

  /// 缓存配置
  final FLXApiCachePolicy? cacheOptions;

  FLXApiOptions(
    this.method,
    this.path, {
    // ... 现有参数 ...
    this.cacheOptions,
  }) : toastBlackCodes = { /* ... */ };
}
```

### 3.2 FLXCommonApi 缓存集成

在 `/Users/tinswin/dzw/tinswin-flutter/flux/packages/flux_core/lib/net/api.dart` 的 `FLXCommonApi.query` 方法中集成缓存逻辑：

```dart
@override
Future<T?> query<T>({CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) async {
  final cacheOptions = options.cacheOptions;

  // 1. 处理缓存策略
  if (cacheOptions != null && cacheOptions.type != FLXApiCacheType.noCache) {
    return await _queryWithCache<T>(
      cacheOptions,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  // 2. 原有网络请求逻辑
  return await _queryNetwork<T>(
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );
}

/// 带缓存的查询
Future<T?> _queryWithCache<T>(
  FLXApiCachePolicy cacheOptions, {
  CancelToken? cancelToken,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
}) async {
  final cache = FLXApiCache();
  final cacheKey = cacheOptions.keyGenerator?.call(options) ?? cache.generateKey(options);

  switch (cacheOptions.type) {
    case FLXApiCacheType.cacheFirst:
      return await _cacheFirstStrategy<T>(cacheKey, cacheOptions, cancelToken, onSendProgress, onReceiveProgress);

    case FLXApiCacheType.cacheThenNetwork:
      return await _cacheThenNetworkStrategy<T>(cacheKey, cacheOptions, cancelToken, onSendProgress, onReceiveProgress);

    case FLXApiCacheType.networkThenCache:
      return await _networkThenCacheStrategy<T>(cacheKey, cacheOptions, cancelToken, onSendProgress, onReceiveProgress);

    case FLXApiCacheType.networkOnlyCache:
      return await _networkOnlyCacheStrategy<T>(cacheKey, cacheOptions, cancelToken, onSendProgress, onReceiveProgress);

    case FLXApiCacheType.cacheOnly:
      return await _cacheOnlyStrategy<T>(cacheKey);

    case FLXApiCacheType.noCache:
      return await _queryNetwork<T>(cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress);
  }
}
```

### 3.3 缓存策略实现

#### cacheFirst - 优先缓存
```dart
Future<T?> _cacheFirstStrategy<T>(
  String cacheKey,
  FLXApiCachePolicy cacheOptions,
  CancelToken? cancelToken,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
) async {
  final cache = FLXApiCache();

  // 尝试从缓存读取
  final cached = await cache.get<T>(cacheKey);
  if (cached != null && !cached.isExpired) {
    logT("Cache HIT: $cacheKey");
    return cached.data;
  }

  // 缓存未命中或过期，发起网络请求
  logT("Cache MISS: $cacheKey, fetching from network");
  final result = await _queryNetwork<T>(
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  // 写入缓存
  if (result != null) {
    await cache.set<T>(
      cacheKey,
      result,
      duration: cacheOptions.duration,
      headers: options.response?.headers.map.map((k, v) => MapEntry(k, v)),
    );
  }

  return result;
}
```

#### cacheThenNetwork - 缓存优先并异步更新
```dart
Future<T?> _cacheThenNetworkStrategy<T>(
  String cacheKey,
  FLXApiCachePolicy cacheOptions,
  CancelToken? cancelToken,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
) async {
  final cache = FLXApiCache();

  // 1. 检查缓存
  final cached = await cache.get<T>(cacheKey);
  if (cached != null && !cached.isExpired) {
    logT("Cache HIT: $cacheKey, returning immediately");

    // 2. 缓存命中：立即返回缓存数据，同时异步更新缓存
    _queryNetwork<T>(
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    ).then((result) {
      if (result != null) {
        cache.set(
          cacheKey,
          result,
          policy: cacheOptions,
        );
      }
    }).catchError((_) {
      // 忽略网络请求错误，不影响主流程
    });

    return cached.data;
  }

  // 3. 缓存未命中或过期：等待网络请求返回
  logT("Cache MISS: $cacheKey, fetching from network");
  final result = await _queryNetwork<T>(
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  // 4. 写入缓存
  if (result != null) {
    await cache.set(cacheKey, result, policy: cacheOptions);
  }

  return result;
}
```

#### networkThenCache - 网络优先
```dart
Future<T?> _networkThenCacheStrategy<T>(
  String cacheKey,
  FLXApiCachePolicy cacheOptions,
  CancelToken? cancelToken,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
) async {
  try {
    // 优先网络请求
    final result = await _queryNetwork<T>(
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    // 写入缓存
    if (result != null) {
      await FLXApiCache().set<T>(
        cacheKey,
        result,
        duration: cacheOptions.duration,
        headers: options.response?.headers.map.map((k, v) => MapEntry(k, v)),
      );
    }

    return result;
  } catch (e) {
    // 网络请求失败，尝试使用缓存
    logT("Network failed, trying cache: $cacheKey");
    final cached = await FLXApiCache().get<T>(cacheKey);
    if (cached != null && !cached.isExpired) {
      logT("Cache HIT for fallback: $cacheKey");
      return cached.data;
    }
    rethrow;
  }
}
```

#### networkOnlyCache - 仅网络并缓存
```dart
Future<T?> _networkOnlyCacheStrategy<T>(
  String cacheKey,
  FLXApiCachePolicy cacheOptions,
  CancelToken? cancelToken,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
) async {
  final result = await _queryNetwork<T>(
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  // 写入缓存
  if (result != null) {
    await FLXApiCache().set<T>(
      cacheKey,
      result,
      duration: cacheOptions.duration,
      headers: options.response?.headers.map.map((k, v) => MapEntry(k, v)),
    );
  }

  return result;
}
```

#### cacheOnly - 仅缓存
```dart
Future<T?> _cacheOnlyStrategy<T>(String cacheKey) async {
  final cached = await FLXApiCache().get<T>(cacheKey);
  if (cached != null && !cached.isExpired) {
    logT("Cache HIT (cacheOnly): $cacheKey");
    return cached.data;
  }
  logT("Cache MISS (cacheOnly): $cacheKey");
  return null;
}
```

## 4. 数据流

### 4.1 cacheFirst 流程
```
用户请求 -> 检查缓存 -> 缓存命中? -> 是:返回缓存数据
                                    -> 否:网络请求 -> 写入缓存 -> 返回数据
```

### 4.2 cacheThenNetwork 流程
```
用户请求 -> 检查缓存 -> 缓存命中? -> 是:立即返回缓存数据 + 异步网络请求更新
                                    -> 否:网络请求 -> 写入缓存 -> 返回数据
```

### 4.3 networkThenCache 流程
```
用户请求 -> 网络请求 -> 成功? -> 是:写入缓存 -> 返回数据
                              -> 否:检查缓存 -> 有且未过期? -> 是:返回缓存数据
                                                        -> 否:抛出异常
```

## 5. 使用示例

### 5.1 基础使用 - 内存缓存30分钟
```dart
final api = FLXGeneralApi<User>(
  FLXApiOptions(
    FLXApiMethod.get,
    '/user/profile',
    url: 'https://api.example.com',
    cacheOptions: FLXApiCachePolicy.memoryCache(
      duration: Duration(minutes: 30),
    ),
  ),
);

final user = await api.fetch<User>();
```

### 5.2 自定义缓存策略
```dart
final api = FLXGeneralApi<List<Post>>(
  FLXApiOptions(
    FLXApiMethod.get,
    '/posts',
    url: 'https://api.example.com',
    cacheOptions: FLXApiCachePolicy(
      type: FLXApiCacheType.cacheThenNetwork,
      duration: Duration(hours: 1),
      maxMemoryCount: 50,
      keyGenerator: (options) => 'posts_${options.params?["category"]}',
    ),
  ),
);
```

### 5.3 网络优先，失败降级
```dart
final api = FLXGeneralApi<Config>(
  FLXApiOptions(
    FLXApiMethod.get,
    '/config',
    url: 'https://api.example.com',
    cacheOptions: FLXApiCachePolicy(
      type: FLXApiCacheType.networkThenCache,
      duration: Duration(hours: 24),
    ),
  ),
);
```

### 5.4 禁用缓存
```dart
final api = FLXGeneralApi<User>(
  FLXApiOptions(
    FLXApiMethod.get,
    '/user/profile',
    url: 'https://api.example.com',
    cacheOptions: FLXApiCachePolicy(
      type: FLXApiCacheType.noCache,
    ),
  ),
);
```

## 6. 边界条件和异常处理

### 6.1 缓存容量限制
- 当内存缓存达到 `maxMemoryCount` 或 `maxMemorySize` 时，使用 LRU 策略淘汰旧缓存
- 清理时优先删除过期缓存

### 6.2 序列化处理
- 缓存数据需要支持序列化/反序列化（使用现有序列化器机制）
- 对复杂对象使用 jsonEncode/jsonDecode
- 对简单类型直接存储

### 6.3 并发控制
- 多个相同请求并发时，只发起一次网络请求，其他等待结果
- 使用 Completer 实现请求去重

### 6.4 异常处理
- 缓存读写失败不影响网络请求
- 磁盘缓存失败时降级到内存缓存
- 序列化失败时跳过缓存

## 7. 受影响的文件

| 文件路径 | 修改类型 | 影响函数 |
|---------|---------|---------|
| `/Users/tinswin/dzw/tinswin-flutter/flux/packages/flux_core/lib/net/api_options.dart` | 新增字段 | FLXApiOptions 构造函数 |
| `/Users/tinswin/dzw/tinswin-flutter/flux/packages/flux_core/lib/net/api.dart` | 新增方法 | FLXCommonApi.query, 新增缓存策略方法 |
| `/Users/tinswin/dzw/tinswin-flutter/flux/packages/flux_core/lib/net/api_enums.dart` | 新增枚举 | FLXApiCachePolicy |
| `/Users/tinswin/dzw/tinswin-flutter/flux/packages/flux_core/lib/net/api_cache.dart` | 新建文件 | FLXApiCache, FLXApiCacheEntry, FLXApiCachePolicy |

## 8. 实现细节

### 8.1 缓存键生成
默认缓存键格式：`{method}_{url}_{path}_{params}_{data}` 的 MD5 哈希

```dart
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
```

### 8.2 内存缓存 LRU 实现
使用 LinkedHashMap 记录访问顺序，容量满时删除最久未使用

### 8.3 缓存大小计算
- 简单类型：使用 sizeof 计算
- 字符串：length * 2 (UTF-16)
- 对象：序列化后的字节长度

## 9. 预期效果

1. **性能提升**：减少重复网络请求，降低响应时间
2. **离线支持**：部分数据可离线访问（cacheOnly 策略）
3. **灵活配置**：支持多种缓存策略，满足不同业务场景
4. **无缝集成**：对现有代码无侵入，通过配置即可启用
5. **可扩展**：预留磁盘缓存接口，后续可扩展持久化能力

## 10. 后续优化方向

1. 支持磁盘持久化缓存（使用 shared_preferences 或 sqflite）
2. 支持缓存预加载
3. 支持缓存版本控制（接口升级时清理旧缓存）
4. 支持缓存统计和监控
5. 支持条件缓存（根据响应头如 Cache-Control 自动判断缓存策略）