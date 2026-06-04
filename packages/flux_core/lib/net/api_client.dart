import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flux_core/log/logger.dart';

import 'api_options.dart';
import 'http_cookie.dart';
import 'http_time.dart';

FLXApiClient apiClient = FLXApiClient();

class FLXApiClient {
  static final FLXApiClient _instance = FLXApiClient._();

  late Dio _dio;

  factory FLXApiClient() {
    return _instance;
  }

  FLXApiClient._() {
    _dio = Dio();
  }

  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  Future<Response<T>> request<T>(
    FLXApiOptions options, {
    Map<String, dynamic>? appendHeaders,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    final defaultHeaders = _buildDefaultHeaders(options);
    if (appendHeaders != null) {
      defaultHeaders.addAll(appendHeaders);
    }
    final customOptions = Options(
      method: options.method.value,
      headers: options.headersByAppend(defaultHeaders),
      sendTimeout: options.customSendTimeout,
      receiveTimeout: options.customReceiveTimeout,
    );
    return _dio.request(
      options.fullUrl,
      data: _dataFromApiParams(options),
      queryParameters: options.params,
      options: customOptions,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Map<String, dynamic> _buildDefaultHeaders(FLXApiOptions options) {
    return {
      'Date': DateTime.now().toHttpTimeString,
      HttpHeaders.contentTypeHeader: options.contentType.value,
    };
  }

  dynamic _dataFromApiParams(FLXApiOptions params) {
    if (params.formData is FormData && params.data is Map) {
      (params.data as Map).forEach((key, value) {
        (params.formData as FormData).fields.add(MapEntry(key.toString(), value.toString()));
      });
      return params.formData;
    }
    return params.data;
  }

  void syncLocalTime(Response? resp) {
    String? dateStr = resp?.headers.value('Date');
    if (dateStr != null) {
      try {
        updateHttpTimeOffset(HttpDate.parse(dateStr));
      } catch (e) {
        logE('_syncLocalTime failed. http date=$dateStr');
      }
    }
  }

  void syncLocalCookie(Response? resp) {
    String? cookieStr = resp?.headers['Set-Cookie']?.first;
    if (cookieStr != null) {
      try {
        updateHttpCookie(cookieStr);
      } catch (e) {
        logE('_syncLocalCookie failed. http cookie=$cookieStr');
      }
    }
  }
}
