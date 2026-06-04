import 'package:json_annotation/json_annotation.dart';

class JsonModel extends JsonSerializable {
  const JsonModel({FieldRename? fieldRename = FieldRename.none})
      : super(fieldRename: fieldRename);
}

/*
自定义model中如果有嵌套的model,或者是数组嵌套了model,转换toJson时可使用此类解决
1.在需要转换的属性上声明 @JsonKey(toJson: xxx) 来指定转换方法
 1.1. @JsonKey(toJson: JsonConvert.instanceToJson) 用来转换嵌套model
 1.2. @JsonKey(toJson: JsonConvert.listToJson) 用来转换数组嵌套model
2.被转换的model类需要继承自 JsonConvert
 */
abstract class JsonConvert {
  Map<String, dynamic> toJson();

  static Map<String, dynamic>? instanceToJson(JsonConvert? instance) =>
      instance?.toJson();

  static List<Map<String, dynamic>>? listToJson(List<JsonConvert>? instance) =>
      instance?.map((e) => e.toJson()).toList();
}
