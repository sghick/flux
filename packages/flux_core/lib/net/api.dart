import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flux_core/log/logger.dart';

import 'api_cache.dart';
import 'api_client.dart';
import 'api_deduplicator.dart';
import 'api_enums.dart';
import 'api_options.dart';
import 'api_request_serializer.dart';
import 'api_response_serializer.dart';

/// 通过此回调获取数据，适用于所有策略中需要两次（缓存+网络）数据回调的场景
typedef FLXDataCallback<T> = void Function(bool fromCache, T? data);

abstract class FLXApi {
  final FLXApiOptions options;

  FLXApiRequestSerializer get requestSerializer => options.requestSerializer ?? FLXGeneralApiRequestSerializer();

  FLXApiResponseSerializer get responseSerializer {
    if (options.responseSerializer == null) {
      throw ArgumentError('responseSerializer must be provided in FLXApiOptions');
    }
    return options.responseSerializer!;
  }

  FLXApi(this.options);

  /// 查询数据
  ///
  /// [onDataSource] 可选回调，用于通知数据来源：
  /// - `fromCache=true, data=...`：来自缓存
  /// - `fromCache=false, data=...`：来自网络请求
  /// 适用于 cacheThenNetwork 等策略需要两次数据回调的场景
  Future<T?> query<T>({
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  });

  Future<List<T>?> queryList<T>({
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  }) {
    return query(cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress, onDataSource: onDataSource).then((
      value,
    ) {
      if (value is List) {
        return value.map((e) => e as T).toList();
      }
      return null;
    });
  }
}

abstract class FLXCommonApi extends FLXApi {
  FLXCommonApi(super.options);

  /// 缓存管理器
  FLXApiCache get _cache => FLXApiCache();

  /// 请求节流器
  FLXApiDeduplicator get _deduplicator => FLXApiDeduplicator();

  @override
  Future<T?> query<T>({
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  }) async {
    // 生成 ApiId（用户自定义优先，否则自动生成）
    final apiId = options.apiId ?? FLXApiDeduplicator.defaultApiIdGenerator(options);

    // 统一经过节流器：同一时间相同 apiId 的请求只发一次
    return _deduplicator.deduplicate<T?>(apiId, () async {
      final cachePolicy = options.cachePolicy;

      // 如果没有配置缓存策略，直接发起网络请求
      if (cachePolicy == null || cachePolicy.type == FLXApiCacheType.noCache) {
        return _queryNetwork<T>(
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
          onDataSource: onDataSource,
        );
      }

      // 使用缓存策略
      final cacheKey = cachePolicy.keyGenerator?.call(options) ?? _cache.generateKey(options);
      return _queryWithCache<T>(
        cacheKey,
        cachePolicy,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        onDataSource: onDataSource,
      );
    });
  }

  /// 带缓存的查询
  Future<T?> _queryWithCache<T>(
    String cacheKey,
    FLXApiCachePolicy cachePolicy, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  }) async {
    switch (cachePolicy.type) {
      case FLXApiCacheType.cacheFirst:
        return _cacheFirstStrategy<T>(
          cacheKey,
          cachePolicy,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
          onDataSource: onDataSource,
        );
      case FLXApiCacheType.cacheThenNetwork:
        return _cacheThenNetworkStrategy<T>(
          cacheKey,
          cachePolicy,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
          onDataSource: onDataSource,
        );
      case FLXApiCacheType.networkThenCache:
        return _networkThenCacheStrategy<T>(
          cacheKey,
          cachePolicy,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
          onDataSource: onDataSource,
        );
      case FLXApiCacheType.optionalCacheThenNetwork:
        return _optionalCacheThenNetworkStrategy<T>(
          cacheKey,
          cachePolicy,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
          onDataSource: onDataSource,
        );
      case FLXApiCacheType.networkOnlyCache:
        return _networkOnlyCacheStrategy<T>(
          cacheKey,
          cachePolicy,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
          onDataSource: onDataSource,
        );
      case FLXApiCacheType.cacheOnly:
        return _cacheOnlyStrategy<T>(cacheKey, cachePolicy, onDataSource: onDataSource);
      case FLXApiCacheType.noCache:
        return _queryNetwork<T>(
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
          onDataSource: onDataSource,
        );
    }
  }

  /// cacheFirst - 优先缓存
  Future<T?> _cacheFirstStrategy<T>(
    String cacheKey,
    FLXApiCachePolicy cachePolicy, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  }) async {
    // 1. 尝试从缓存读取原始数据
    final cachedData = await _cache.get(cacheKey, policy: cachePolicy);
    if (cachedData != null) {
      logT("Cache HIT (cacheFirst): $cacheKey");
      // 通过序列化器反序列化
      final result = _deserializeCacheData<T>(cachedData);
      onDataSource?.call(true, result);
      return result;
    }

    // 2. 缓存未命中，发起网络请求
    logT("Cache MISS (cacheFirst): $cacheKey, fetching from network");
    final result = await _queryNetwork<T>(
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      onDataSource: onDataSource,
    );

    // 3. 写入缓存（存储序列化后的数据）
    if (result != null) {
      await _cache.set(cacheKey, result, policy: cachePolicy);
    }

    return result;
  }

  /// cacheThenNetwork - 缓存优先并异步更新
  Future<T?> _cacheThenNetworkStrategy<T>(
    String cacheKey,
    FLXApiCachePolicy cachePolicy, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  }) async {
    // 1. 检查缓存
    final cachedData = await _cache.get(cacheKey, policy: cachePolicy);
    if (cachedData != null) {
      logT("Cache HIT (cacheThenNetwork): $cacheKey, returning immediately");

      // 2. 缓存命中：立即返回缓存数据，同时异步更新缓存
      final cacheResult = _deserializeCacheData<T>(cachedData);
      onDataSource?.call(true, cacheResult);

      _queryNetwork<T>(cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress)
          .then((result) {
            if (result != null) {
              _cache.set(cacheKey, result, policy: cachePolicy);
              onDataSource?.call(false, result);
            }
          })
          .catchError((_) {
            // 忽略网络请求错误，不影响主流程
          });

      return cacheResult;
    }

    // 3. 缓存未命中：等待网络请求返回
    logT("Cache MISS (cacheThenNetwork): $cacheKey, fetching from network");
    final result = await _queryNetwork<T>(
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      onDataSource: onDataSource,
    );

    // 4. 写入缓存
    if (result != null) {
      await _cache.set(cacheKey, result, policy: cachePolicy);
    }

    return result;
  }

  /// networkThenCache - 网络优先降级策略
  Future<T?> _networkThenCacheStrategy<T>(
    String cacheKey,
    FLXApiCachePolicy cachePolicy, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  }) async {
    try {
      // 1. 优先网络请求
      final result = await _queryNetwork<T>(
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        onDataSource: onDataSource,
      );

      // 2. 写入缓存
      if (result != null) {
        await _cache.set(cacheKey, result, policy: cachePolicy);
      }

      return result;
    } catch (e) {
      // 3. 网络请求失败，尝试使用缓存
      logT("Network failed (networkThenCache): $cacheKey, trying cache");
      final cachedData = await _cache.get(cacheKey, policy: cachePolicy);
      if (cachedData != null) {
        logT("Cache HIT (networkThenCache fallback): $cacheKey");
        final result = _deserializeCacheData<T>(cachedData);
        onDataSource?.call(true, result);
        return result;
      }
      rethrow;
    }
  }

  /// networkOnlyCache - 仅网络并缓存
  Future<T?> _networkOnlyCacheStrategy<T>(
    String cacheKey,
    FLXApiCachePolicy cachePolicy, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  }) async {
    final result = await _queryNetwork<T>(
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      onDataSource: onDataSource,
    );

    // 写入缓存
    if (result != null) {
      await _cache.set(cacheKey, result, policy: cachePolicy);
    }

    return result;
  }

  /// cacheOnly - 仅缓存
  Future<T?> _cacheOnlyStrategy<T>(String cacheKey, FLXApiCachePolicy cachePolicy, {FLXDataCallback<T>? onDataSource}) async {
    final cachedData = await _cache.get(cacheKey, policy: cachePolicy);
    if (cachedData != null) {
      logT("Cache HIT (cacheOnly): $cacheKey");
      final result = _deserializeCacheData<T>(cachedData);
      onDataSource?.call(true, result);
      return result;
    }
    logT("Cache MISS (cacheOnly): $cacheKey");
    return null;
  }

  /// optionalCacheThenNetworkStrategy - 可选缓存策略
  Future<T?> _optionalCacheThenNetworkStrategy<T>(
    String cacheKey,
    FLXApiCachePolicy cachePolicy, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  }) async {
    if (onDataSource != null) {
      return _cacheThenNetworkStrategy(
        cacheKey,
        cachePolicy,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        onDataSource: onDataSource,
      );
    } else {
      return _queryNetwork<T>(
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        onDataSource: onDataSource,
      );
    }
  }

  /// 反序列化缓存数据
  /// cachedData 可能是序列化后的 json 字符串或原始 Map
  T? _deserializeCacheData<T>(dynamic cachedData) {
    // 如果是字符串，尝试 jsonDecode
    if (cachedData is String) {
      try {
        cachedData = jsonDecode(cachedData);
      } catch (_) {
        // 如果不是有效的 json 字符串，直接返回原值
      }
    }

    // 如果是 Map，使用序列化器反序列化
    if (cachedData is Map || cachedData is List) {
      return responseSerializer.parseResponse<T>(cachedData, this);
    }

    // 其他情况直接返回
    return cachedData as T?;
  }

  /// 网络请求（原有逻辑）
  Future<T?> _queryNetwork<T>({
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    FLXDataCallback<T>? onDataSource,
  }) async {
    final methodName = options.method.name.toUpperCase();
    try {
      _logRequest(methodName);
      Response resp = await apiClient.request(
        options,
        appendHeaders: requestSerializer.customHeaders(options),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      options.response = resp;
      _logResponse(methodName, resp);
      if (options.syncLocalTime) {
        apiClient.syncLocalTime(resp);
      }
      apiClient.syncLocalCookie(resp);
      final result = await responseSerializer.apiHandleResponse<T>(resp, this);
      onDataSource?.call(false, result);
      return result;
    } catch (e, s) {
      _logError(methodName, e, s);
      return responseSerializer.apiHandleError<T>(e, s, this);
    }
  }

  void _logRequest(String methodName) {
    logT(
      "\n>>>>>>>>>>>>>>>>>> API Send...: ($methodName) >>>>>>>>>>>>>>>>>>\n"
      "$methodName ${options.url}${options.path} \n"
      "queries:${options.params} body:${options.data} \n"
      ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n",
    );
  }

  void _logResponse(String methodName, Response resp) {
    logT(
      "\n<<<<<<<<<<<<<<<<<<<< API Response:($methodName) <<<<<<<<<<<<<<<<<<<<\n"
      "$methodName ${resp.requestOptions.uri} \n"
      "queries:${options.params} body:${options.data} \n"
      "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n",
    );
  }

  void _logError(String methodName, dynamic e, StackTrace s) {
    logT(
      "\n^^^^^^^^^^^^^^^^^^^^ API Error:($methodName) ^^^^^^^^^^^^^^^^^^^^\n"
      "$methodName ${options.path} \n"
      "queries:${options.params} body:${options.data} \n"
      "headers:${options.response?.requestOptions.headers}\n"
      "response:${options.response} \n"
      "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n",
    );
    if (e is DioException) {
      logE(e.response);
    }
  }
}
