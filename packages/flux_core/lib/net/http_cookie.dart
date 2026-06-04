String _httpCookieStr = '';

String get httpCookieStr {
  return _httpCookieStr;
}

void updateHttpCookie(String? cookieStr) {
  if (cookieStr == null) return;
  _httpCookieStr = cookieStr;
}
