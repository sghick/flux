import 'package:flutter/cupertino.dart';
import 'package:flux_core/log/logger.dart';

final jumpManager = PageJumpManager.sharedInstance;

typedef AuthHandler = void Function({VoidCallback? onPassed, VoidCallback? onCanceled, dynamic authType});

typedef PageJumpParser = dynamic Function(String url, Map<String, dynamic>? parameters);
typedef PageJumpUnhandledUrlHandler = dynamic Function(String url, Uri uri, dynamic object);
typedef PageJumpRouteAction = dynamic Function(PageJumpEvent event);

class PageJumpOptions {
  /// 跳转解析器
  final Map<String, PageJumpConfig> jumpConfigs;

  /// 通用跳转处理
  final PageJumpRouteAction routeActionHandler;

  /// scheme验证, 为null时则不进行scheme验证
  final String? appScheme;

  /// web跳转处理
  final PageJumpConfig? webJumpConfig;

  /// 未处理的native url处理
  final PageJumpUnhandledUrlHandler? unhandledNativeUrlHandler;

  /// 未处理的url处理
  final PageJumpUnhandledUrlHandler? unhandledUrlHandler;

  /// 跳转检查
  final AuthHandler? authHandler;

  PageJumpOptions({
    required this.jumpConfigs,
    required this.routeActionHandler,
    this.appScheme,
    this.webJumpConfig,
    this.unhandledNativeUrlHandler,
    this.unhandledUrlHandler,
    this.authHandler,
  });
}

class PageJumpManager {
  late PageJumpOptions options;
  Uri? uri;

  static PageJumpManager? _instance;

  static PageJumpManager get sharedInstance {
    _instance ??= PageJumpManager();
    return _instance!;
  }

  void init(PageJumpOptions options) {
    this.options = options;
  }

  void setJumpUrl(Uri? uri) {
    this.uri = uri;
  }

  Future<T?> jumpIfNeeded<T>({bool autoClear = true}) {
    final uri = this.uri;
    if (autoClear) {
      this.uri = null;
    }
    return jump(uri?.toString());
  }

  Future<T?> jump<T>(String? url, {dynamic object}) {
    if (url == null || url.isEmpty) {
      return Future.value();
    }
    Uri uri = Uri.parse(url);
    String scheme = uri.scheme;
    if (scheme.startsWith('http') || scheme.startsWith('https')) {
      return _toHttp(url, uri, object);
    } else if ((options.appScheme == null) || (options.appScheme != null && scheme.startsWith(options.appScheme!))) {
      return _toNative(url, uri, object);
    } else {
      return options.unhandledUrlHandler?.call(url, uri, object);
    }
  }

  Future<T?> _toNative<T>(String url, Uri uri, dynamic object) {
    PageJumpConfig? handler = options.jumpConfigs[uri.host];
    try {
      if (handler != null) {
        logD('jump:$url');
        return handler.jumpByUrl(url, uri, object);
      } else {
        if (options.unhandledNativeUrlHandler != null) {
          return options.unhandledNativeUrlHandler?.call(url, uri, object);
        } else {
          logD('jumpHandlers/unhandledNativeJumpHandler not response url or undefined unhandledNativeUrlHandler:$url');
          return Future.value();
        }
      }
    } catch (e) {
      logD('jumpHandlers error:$url');
      return Future.value();
    }
  }

  Future<T?> _toHttp<T>(String url, Uri uri, dynamic object) {
    PageJumpConfig? handler = options.webJumpConfig;
    try {
      if (handler != null) {
        logD('web jump:$url');
        return handler.jumpByUrl(url, uri, object);
      } else {
        logD('undefined webJumpHandler:$url');
        return Future.value();
      }
    } catch (e) {
      logD('webJumpHandler error:$url');
      return Future.value();
    }
  }
}

String? parseString(Object? parameters, String name) {
  if ((parameters is Map) && parameters.containsKey(name)) {
    return parameters[name]?.toString();
  }
  return null;
}

int? parseInt(Object? parameters, String name) {
  if ((parameters is Map) && parameters.containsKey(name)) {
    return int.parse(parameters[name]);
  }
  return null;
}

bool? parseBool(Object? parameters, String name) {
  if ((parameters is Map) && parameters.containsKey(name)) {
    return int.parse(parameters[name]) != 0;
  }
  return null;
}

class PageJumpEvent {
  final String url;
  final String target;
  final dynamic arguments;
  final dynamic object;

  PageJumpEvent(this.url, this.target, this.arguments, this.object);

  PageJumpEvent redirect({String? url, String? target, dynamic arguments, dynamic object}) =>
      PageJumpEvent(url ?? this.url, target ?? this.target, arguments ?? this.arguments, object ?? this.object);
}

class PageJumpConfig {
  final String target;
  final PageJumpParser? parser;
  final PageJumpRouteAction? action;
  final dynamic authType; // 如果为null,则不会调用checkingHandler

  PageJumpConfig(this.target, {this.parser, this.action, this.authType});

  PageJumpEvent eventForJump(String url, Uri uri, dynamic object) {
    PageJumpParser parser = this.parser ?? _defaultParser;
    Map? parameters = uri.queryParameters.isNotEmpty ? uri.queryParameters : null;
    return PageJumpEvent(url, target, parser(url, parameters as Map<String, dynamic>?), object);
  }

  Future<T?> jumpByUrl<T>(String url, Uri uri, dynamic object) {
    return jumpByEvent(eventForJump(url, uri, object));
  }

  Future<T?> jumpByEvent<T>(PageJumpEvent event) {
    PageJumpRouteAction action = this.action ?? PageJumpManager.sharedInstance.options.routeActionHandler;
    if (authType != null) {
      if (PageJumpManager.sharedInstance.options.authHandler != null) {
        PageJumpManager.sharedInstance.options.authHandler!(
          onPassed: () {
            action(event);
          },
          onCanceled: () {
            logD('jump requires auth: $authType');
          },
          authType: authType,
        );
      }
      return Future.value();
    } else {
      return action(event);
    }
  }

  PageJumpParser get _defaultParser =>
      (url, parameters) => parameters;
}
