import 'dart:convert';

import 'package:dio/dio.dart';

import 'api.dart';
import 'api_error.dart';
import 'type_parser.dart';

/// API响应序列化器
/// 提供类型安全的自动反序列化功能
abstract class FLXApiResponseSerializer<T> {
  FLXApiResponseSerializer({this.typeParser});

  final FLXTypeParser<T>? typeParser;

  Future<U?> apiHandleResponse<U>(Response resp, FLXApi api) {
    final respData = FLXResponseUtils.decryptRespDataIfNeeded(resp.data);
    return Future.value(handleResponse<U>(resp, respData, api));
  }

  U? handleResponse<U>(Response resp, dynamic respData, FLXApi api) {
    try {
      return _handleTypedResponse(respData) as U?;
    } catch (e) {
      throw FLXNetError.parseError.eWith(msg: 'Parsing failed: $e', response: resp);
    }
  }

  /// 处理类型化响应
  dynamic _handleTypedResponse(dynamic respData) {
    if (respData == null) {
      return null;
    }

    // 如果没有提供类型解析器，返回原始数据
    if (typeParser == null) {
      return respData;
    }

    // 处理空数据
    if (respData is List && respData.isEmpty) {
      if (typeParser!.isListType) {
        return <T>[];
      }
      return null;
    }
    if (respData is Map && respData.isEmpty) {
      return null;
    }

    // 根据类型解析器处理数据
    if (respData is List && typeParser!.isListType) {
      return typeParser!.parseList(respData);
    } else if (respData is Map && !typeParser!.isListType) {
      return typeParser!.parseSingle(respData as Map<String, dynamic>);
    } else if (respData is Map && typeParser!.isListType) {
      // 如果返回的是单个对象但使用的是list解析器，尝试包装成列表
      return typeParser!.parseList([respData as Map<String, dynamic>]);
    }

    return respData;
  }

  Future<U?> apiHandleError<U>(dynamic e, StackTrace? s, FLXApi api) {
    final error = handleError<U>(e, s, api);
    if (api.options.canToastError(error.code) == true) {
      apiWillToastError(error, s, api);
    }
    return Future.error(error);
  }

  FLXNetError handleError<U>(dynamic e, StackTrace? s, FLXApi api) {
    if (e is FLXNetError) {
      return e;
    } else {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        try {
          apiHandleResponse(e.response!, api);
        } catch (e) {
          return (e is FLXNetError) ? e : FLXNetError.netError.eWith(msg: e.toString());
        }
      }
      return FLXNetError.defaultError(msg: e.toString());
    }
  }

  void apiWillToastError<U>(FLXNetError e, StackTrace? s, FLXApi api);
}

/// 默认的 API 响应序列化器实现
class FLXDefaultApiResponseSerializer<T> extends FLXApiResponseSerializer<T> {
  FLXDefaultApiResponseSerializer({super.typeParser});

  @override
  void apiWillToastError<U>(FLXNetError e, StackTrace? s, FLXApi api) {
    // 默认实现，不执行任何操作
  }
}

class FLXResponseUtils {
  static dynamic decryptRespDataIfNeeded(dynamic data) {
    var rtn = data;
    if (rtn is String) {
      var obj = _tryToBase64Decode(rtn);
      if (obj != null) {
        var dataStr = utf8.decode(obj, allowMalformed: true);
        rtn = _tryToJson(dataStr);
      }
    }
    return rtn;
  }

  static dynamic _tryToBase64Decode(String source) {
    try {
      return base64Decode(source);
    } catch (e) {
      return null;
    }
  }

  static dynamic _tryToJson(dynamic value) {
    try {
      return json.decode(value);
    } catch (e) {
      return null;
    }
  }
}
