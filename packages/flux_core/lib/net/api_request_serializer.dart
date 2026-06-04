import 'api_options.dart';

abstract class FLXApiRequestSerializer {
  Map<String, dynamic>? customHeaders(FLXApiOptions options);
}

/// 默认的通用API请求序列化器
/// 提供基础的请求头处理逻辑
class FLXGeneralApiRequestSerializer extends FLXApiRequestSerializer {
  @override
  Map<String, dynamic>? customHeaders(FLXApiOptions options) {
    // 默认实现，可以由子类重写
    return null;
  }
}
