import 'dart:io';

import './web_js_cookie.dart';
import '../log/logger.dart';

class WebJsParam {
  final Map<String, dynamic> _formats = {};

  void addInt(String key, int? value) {
    _formats[key] = "${value ?? 0}";
  }

  void addBool(String key, bool? value) {
    _formats[key] = "${value ?? false}";
  }

  void addString(String key, String? value) {
    _formats[key] = "'${value ?? ''}'";
  }

  String fillWithJSString(String? jsString) {
    if (jsString == null) return '';
    String result = jsString;
    String match = jsString.substring(
      jsString.indexOf('(') + 1,
      jsString.lastIndexOf(')'),
    );
    List<String> params = match.split(',');
    for (int i = 0; i < params.length; i++) {
      String e = params[i];
      result = result.replaceFirst(e, _formats[e] ?? "''");
    }
    return result;
  }

  Future<void> evaluateJSCallback(
    String? callbackJs,
    Function(String? js)? runJavaScript,
  ) {
    if (callbackJs == null || runJavaScript == null) {
      return Future.value();
    }

    String js = fillWithJSString(callbackJs);
    logD('执行js:$js');
    return runJavaScript(js);
  }

  Future<void> evaluateJSCookie(
    List<Cookie>? cookies,
    Function(String? js)? runJavaScript,
  ) {
    if (cookies?.isEmpty ?? true) {
      logD('evaluateJSCookie return:cookies is null or empty');
      return Future.value();
    }
    if (runJavaScript == null) {
      logD('evaluateJSCookie return:runJavaScript is null');
      return Future.value();
    }
    String js = WebJsCookieEx.javaScriptValueWithCookies(cookies);
    logD('写入cookie:$js');
    return runJavaScript(js);
  }
}
