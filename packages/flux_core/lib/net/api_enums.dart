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
