import 'dart:convert';
import 'dart:typed_data';

extension FLXUnit8ListExt on Uint8List? {
  String? get string => this != null ? utf8.decode(this!) : null;

  dynamic get jsonObject => string.jsonObject;
}

extension StringExt on String? {
  Uint8List? get uint8List => this != null ? utf8.encode(this!) : null;

  dynamic get jsonObject => this != null ? json.decode(this!) : null;
}

extension ObjectExt on Object? {
  Uint8List? get jsonUint8List => jsonString.uint8List;

  String? get jsonString => this != null ? json.encode(this) : null;
}
