import 'dart:io';

extension WebJsCookieEx on Cookie {
  String javaScriptValue() {
    return "document.cookie='${toString()};'";
  }

  static String javaScriptValueWithCookies(List<Cookie>? cookies) {
    if (cookies?.isEmpty ?? true) return '';
    String str = '';
    for (var element in cookies!) {
      str = '$str${element.javaScriptValue()}';
    }
    return str;
  }

  static Map<String, String>? requestHeaderFieldsWithCookies(
      List<Cookie>? cookies) {
    if (cookies?.isEmpty ?? true) return null;
    String str = '';
    for (var element in cookies!) {
      str = '$str${element.toString()};';
    }
    return {'Cookie': str};
  }
}
