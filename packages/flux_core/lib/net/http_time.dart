import 'dart:io';
import 'package:ntp/ntp.dart';
import 'package:flux_core/log/logger.dart';

int _httpTimeOffset = 0;

int get httpTimeOffset {
  return _httpTimeOffset;
}

void updateHttpTimeOffset(DateTime? httpDate) {
  if (httpDate == null) return;
  _httpTimeOffset =
      httpDate.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch;
}

Future<void> updateNtpTimeOffset() async {
  return NTP.getNtpOffset(lookUpAddress: 'time1.google.com').then((offset) {
    _httpTimeOffset = offset;
  }).catchError((e) {
    logT('updateNTPOffset failed: $e');
  });
}

extension FLXHttpTimeExt on DateTime {
  DateTime get toHttpTime {
    return add(Duration(milliseconds: httpTimeOffset));
  }

  String get toHttpTimeString {
    return HttpDate.format(toHttpTime);
  }
}
