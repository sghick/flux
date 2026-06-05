abstract class FLXError implements Exception {
  final String domain;
  final int code;
  final String? msg;

  FLXError(this.domain, this.code, this.msg);

  @override
  String toString() => msg ?? '';
}

