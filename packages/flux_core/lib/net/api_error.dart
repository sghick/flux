import 'package:dio/dio.dart';
import 'package:flux_core/errors/errors.dart';

class FLXNetError extends FLXError {
  final Response? response;
  dynamic errorResponse;

  FLXNetError(super.domain, super.code, super.msg, this.response);

  static const String netExceptionDomain = "ifk.network.error.domain";

  static const int netErrorCode = 1000;
  static const int parseErrorCode = 1001;
  static const int socketErrorCode = 1002;
  static const int httpErrorCode = 1003;
  static const int connectTimeoutErrorCode = 1004;
  static const int sendTimeoutErrorCode = 1005;
  static const int receiveTimeoutErrorCode = 1006;
  static const int cancelErrorCode = 1007;
  static const int unknownErrorCode = 9999;

  FLXNetError eWith({String? msg, Response? response}) => FLXNetError(domain, code, msg ?? this.msg, response ?? this.response);

  static error(int code, {String? msg, Response? response}) => FLXNetError(netExceptionDomain, code, msg, response);

  static defaultError({String? msg, Response? response}) => FLXNetError.error(unknownErrorCode, msg: msg, response: response);

  static FLXNetError get unknownError => FLXNetError.error(unknownErrorCode, msg: 'Unknown Error');

  static FLXNetError get netError => FLXNetError.error(netErrorCode, msg: 'Network anomaly, please check your network');

  static FLXNetError get parseError => FLXNetError.error(parseErrorCode, msg: 'Data parsing error');

  static FLXNetError get socketError => FLXNetError.error(socketErrorCode, msg: 'Network anomaly, please check your network');

  static FLXNetError get httpError => FLXNetError.error(httpErrorCode, msg: 'Server exception, please try again later!');

  static FLXNetError get connectTimeoutError => FLXNetError.error(connectTimeoutErrorCode, msg: 'Connection timeout');

  static FLXNetError get sendTimeoutError => FLXNetError.error(sendTimeoutErrorCode, msg: 'Request Timeout');

  static FLXNetError get receiveTimeoutError => FLXNetError.error(receiveTimeoutErrorCode, msg: 'Response timeout');

  static FLXNetError get cancelError => FLXNetError.error(cancelErrorCode, msg: 'Cancel Request');
}
