import 'package:dio/dio.dart';

import 'api.dart';
import 'api_response_serializer.dart';
import 'type_parser.dart';

export 'type_parser.dart';

/// 泛型通用API类
/// 支持类型安全的自动反序列化
class FLXGeneralApi<T> extends FLXCommonApi {
  FLXGeneralApi(super.options) {
    // 如果 options 中没有设置序列化器，则根据 typeParser 设置
    options.responseSerializer ??= FLXDefaultApiResponseSerializer<T>(
      typeParser: options.typeParser as FLXTypeParser<T>?,
    );
  }

  /// 查询并返回泛型结果
  Future<T?> fetch({
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return query<T>(
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }
}