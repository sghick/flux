import 'package:dio/dio.dart';
import 'package:flux_core/log/logger.dart';

import 'api_client.dart';
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

  @override
  Future<T?> query<T>({CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) async {
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
