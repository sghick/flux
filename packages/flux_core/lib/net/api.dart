import 'package:dio/dio.dart';
import 'package:flux_core/log/logger.dart';

import 'api_cache.dart';
import 'api_client.dart';
import 'api_enums.dart';
import 'api_options.dart';
import 'api_request_serializer.dart';
import 'api_response_serializer.dart';

abstract class FLXApi {
  final FLXApiOptions options;

  FLXApiRequestSerializer get requestSerializer =>
      options.requestSerializer ?? FLXGeneralApiRequestSerializer();

  FLXApiResponseSerializer get responseSerializer {
    if (options.responseSerializer == null) {
      throw ArgumentError('responseSerializer must be provided in FLXApiOptions');
    }
    return options.responseSerializer!;
  }

  FLXApi(this.options);

  Future<T?> query<T>({CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress});

  Future<List<T>?> queryList<T>({CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) {
    return query(cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress).then((value) {
      if (value is List) {
        return value.map((e) => e as T).toList();
      }
      return value;
    });
  }
}

abstract class FLXCommonApi extends FLXApi {
  FLXCommonApi(super.options);

  /// 缓存管理器
  FLXApiCache get _cache => FLXApiCache();

  @override
  Future<T?> query<T>({CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) async {
    final cachePolicy = options.cachePolicy;

    // 如果没有配置缓存策略，直接发起网络请求
    if (cachePolicy == null || cachePolicy.type == FLXApiCacheType.noCache) {
      return _queryNetwork<T>(
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
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
    );
  }

  /// 带缓存的查询
  Future<T?> _queryWithCache<T>(
    String cacheKey,
    FLXApiCachePolicy cachePolicy, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    // 使用请求去重
    return _cache.getOrCreate<T>(cacheKey, () async {
      switch (cachePolicy.type) {
        case FLXApiCacheType.cacheFirst:
          return _cacheFirstStrategy<T>(cacheKey, cachePolicy, cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress);
        case FLXApiCacheType.cacheThenNetwork:
          return _cacheThenNetworkStrategy<T>(cacheKey, cachePolicy, cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress);
        case FLXApiCacheType.networkThenCache:
          return _networkThenCacheStrategy<T>(cacheKey, cachePolicy, cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress);
        case FLXApiCacheType.networkOnlyCache:
          return _networkOnlyCacheStrategy<T>(cacheKey, cachePolicy, cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress);
        case FLXApiCacheType.cacheOnly:
          return _cacheOnlyStrategy<T>(cacheKey, cachePolicy);
        case FLXApiCacheType.noCache:
          return _queryNetwork<T>(cancelToken: cancelToken, onSendProgress: onSendProgress, onReceiveProgress: onReceiveProgress);
      }
    });
  }

  /// cacheFirst - 优先缓存
  Future<T?> _cacheFirstStrategy<T>(
    String cacheKey,
    FLXApiCachePolicy cachePolicy, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    // 1. 尝试从缓存读取
    final cached = await _cache.get<T>(cacheKey, policy: cachePolicy);
    if (cached != null) {
      logT("Cache HIT (cacheFirst): $cacheKey");
      return cached;
    }

    // 2. 缓存未命中，发起网络请求
    logT("Cache MISS (cacheFirst): $cacheKey, fetching from network");
    final result = await _queryNetwork<T>(
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    // 3. 写入缓存
    if (result != null) {
      await _cache.set<T>(cacheKey, result, policy: cachePolicy);
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
  }) async {
    // 1. 检查缓存
    final cached = await _cache.get<T>(cacheKey, policy: cachePolicy);
    if (cached != null) {
      logT("Cache HIT (cacheThenNetwork): $cacheKey, returning immediately");

      // 2. 缓存命中：立即返回缓存数据，同时异步更新缓存
      _queryNetwork<T>(
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ).then((result) {
        if (result != null) {
          _cache.set<T>(cacheKey, result, policy: cachePolicy);
        }
      }).catchError((_) {
        // 忽略网络请求错误，不影响主流程
      });

      return cached;
    }

    // 3. 缓存未命中：等待网络请求返回
    logT("Cache MISS (cacheThenNetwork): $cacheKey, fetching from network");
    final result = await _queryNetwork<T>(
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    // 4. 写入缓存
    if (result != null) {
      await _cache.set<T>(cacheKey, result, policy: cachePolicy);
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
  }) async {
    try {
      // 1. 优先网络请求
      final result = await _queryNetwork<T>(
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      // 2. 写入缓存
      if (result != null) {
        await _cache.set<T>(cacheKey, result, policy: cachePolicy);
      }

      return result;
    } catch (e) {
      // 3. 网络请求失败，尝试使用缓存
      logT("Network failed (networkThenCache): $cacheKey, trying cache");
      final cached = await _cache.get<T>(cacheKey, policy: cachePolicy);
      if (cached != null) {
        logT("Cache HIT (networkThenCache fallback): $cacheKey");
        return cached;
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
  }) async {
    final result = await _queryNetwork<T>(
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    // 写入缓存
    if (result != null) {
      await _cache.set<T>(cacheKey, result, policy: cachePolicy);
    }

    return result;
  }

  /// cacheOnly - 仅缓存
  Future<T?> _cacheOnlyStrategy<T>(String cacheKey, FLXApiCachePolicy cachePolicy) async {
    final cached = await _cache.get<T>(cacheKey, policy: cachePolicy);
    if (cached != null) {
      logT("Cache HIT (cacheOnly): $cacheKey");
      return cached;
    }
    logT("Cache MISS (cacheOnly): $cacheKey");
    return null;
  }

  /// 网络请求（原有逻辑）
  Future<T?> _queryNetwork<T>({CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) async {
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
      return responseSerializer.apiHandleResponse<T>(resp, this);
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
