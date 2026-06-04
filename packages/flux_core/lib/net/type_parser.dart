/// @Deprecated 用于替代的方案：使用 FLXTypeParser 配合 ModelFromJson 函数
abstract class FLXJsonSerializable {
  /// 从JSON创建实例
  factory FLXJsonSerializable.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('fromJson must be implemented');
  }

  /// 转换为JSON
  Map<String, dynamic> toJson();
}

/// Model类型定义函数
typedef ModelFromJson<T> = T Function(Map<String, dynamic> json);

/// 类型解析器 - 不使用反射，通过函数传递实现
/// 支持单个对象和列表对象的解析
class FLXTypeParser<T> {
  final ModelFromJson<T>? fromJson;
  final bool _isListType;

  FLXTypeParser._({this.fromJson, required bool isListType}) : _isListType = isListType;

  /// 创建单个对象解析器
  factory FLXTypeParser.single(ModelFromJson<T> fromJson) {
    return FLXTypeParser._(fromJson: fromJson, isListType: false);
  }

  /// 创建列表对象解析器
  factory FLXTypeParser.list(ModelFromJson<T> itemFromJson) {
    return FLXTypeParser._(fromJson: itemFromJson, isListType: true);
  }

  /// 检查是否为List类型
  bool get isListType => _isListType;

  /// 解析单个对象
  T parseSingle(Map<String, dynamic> json) {
    if (fromJson == null) {
      throw Exception('fromJson parser not provided for type $T');
    }
    return fromJson!(json);
  }

  /// 解析列表
  List<T> parseList(List<dynamic> jsonList) {
    if (fromJson == null) {
      throw Exception('fromJson parser not provided for type $T');
    }
    return jsonList.map((json) => fromJson!(json as Map<String, dynamic>)).toList();
  }
}