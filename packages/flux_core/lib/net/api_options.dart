import 'package:dio/dio.dart';

import 'api_cache.dart';
import 'api_enums.dart';
import 'api_request_serializer.dart';
import 'api_response_serializer.dart';
import 'type_parser.dart';

class FLXApiOptions {
  final FLXApiMethod method;
  final String path;
  final String? url;
  final Map<String, dynamic>? params; // 用于GET,DELETE请求的参数
  final dynamic data; // 用于POST,PUT请求的参数
  final dynamic formData;
  final Duration? customSendTimeout;
  final Duration? customReceiveTimeout;
  final bool syncLocalTime;
  final bool autoToastNetError;
  final Set<int>? initialToastBlackCodes;
  final Set<int> toastBlackCodes;
  final FLXApiContentType contentType;
  Map<String, dynamic>? customHeaders;
  Response? response;
  FLXApiRequestSerializer? requestSerializer;
  FLXApiResponseSerializer? responseSerializer;
  final FLXTypeParser? typeParser;

  /// 缓存策略配置
  final FLXApiCachePolicy? cachePolicy;

  /// 自定义 Api 标识，用于请求去重
  ///
  /// 多个相同 apiId 的并发请求只会真正发起一次网络请求，
  /// 其余请求等待第一个请求返回后共享结果。
  /// 不传则自动根据 method + url + params + data 生成 MD5 标识。
  final String? apiId;

  FLXApiOptions(
    this.method,
    this.path, {
    required this.url,
    this.params,
    this.data,
    this.formData,
    this.customSendTimeout = const Duration(seconds: 30),
    this.customReceiveTimeout = const Duration(seconds: 30),
    this.syncLocalTime = true,
    this.autoToastNetError = true,
    this.initialToastBlackCodes,
    this.contentType = FLXApiContentType.formUrl,
    this.customHeaders,
    this.requestSerializer,
    this.responseSerializer,
    this.typeParser,
    this.cachePolicy,
    this.apiId,
  }) : toastBlackCodes = {} {
    if (initialToastBlackCodes != null) {
      toastBlackCodes.addAll(initialToastBlackCodes!);
    }
  }

  bool get isHttp => url?.startsWith('http://') ?? false;

  bool get isHttps => url?.startsWith('https://') ?? false;

  bool get isFile => url?.startsWith('file://') ?? false;

  String get fullUrl => (url != null) ? Uri.parse(url!).replace(path: path).toString() : path;

  Map<String, dynamic>? headersByAppend(Map<String, dynamic>? headers) {
    final hds = {...?customHeaders, ...?headers};
    return hds.isNotEmpty ? hds : null;
  }

  bool canToastError(int? code) {
    return autoToastNetError && !toastBlackCodes.contains(code);
  }

  @override
  String toString() {
    return '{\n'
        '  ${method.value}:$url$path \n'
        '  queries:$params \n'
        '  body:$data \n'
        '  formData:$formData \n'
        '  customSendTimeout:$customSendTimeout \n'
        '  customReceiveTimeout:$customReceiveTimeout \n'
        '  customHeaders:$customHeaders \n'
        '  syncLocalTime:$syncLocalTime \n'
        '}';
  }
}
