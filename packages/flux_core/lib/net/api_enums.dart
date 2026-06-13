import 'package:dio/dio.dart';

enum FLXApiMethod {
  get("GET"),
  post("POST"),
  put("PUT"),
  delete("DELETE"),
  patch("PATCH");

  final String value;

  const FLXApiMethod(this.value);

  static FLXApiMethod fromValue(dynamic value, {FLXApiMethod defaultEnum = FLXApiMethod.get}) {
    return FLXApiMethod.values.firstWhere((e) => e.value == value, orElse: () => defaultEnum);
  }
}

enum FLXApiCacheType {
  /// 不使用缓存，每次都发起网络请求
  noCache,

  /// 优先使用缓存，如果没有缓存或缓存过期，发起网络请求
  cacheFirst,

  /// 同时返回缓存和网络请求结果（缓存立即返回，网络请求异步更新缓存）
  cacheThenNetwork,

  /// 可选缓存，如果有onDataSource参数，则执行cacheThenNetwork策略，否则执行noCache策略。
  optionalCacheThenNetwork,

  /// 优先使用网络请求，失败时使用缓存
  networkThenCache,

  /// 仅网络请求，成功后更新缓存
  networkOnlyCache,

  /// 仅使用缓存，不发起网络请求
  cacheOnly,
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

enum FLXApiContentType {
  json,
  formUrl,
  textPlain,
  multipartFormData;

  String get value => valuesMap[this]!;

  Map<FLXApiContentType, String> get valuesMap => {
    json: Headers.jsonContentType,
    formUrl: Headers.formUrlEncodedContentType,
    textPlain: Headers.textPlainContentType,
    multipartFormData: Headers.multipartFormDataContentType,
  };
}
