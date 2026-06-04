abstract class FLXLoadingHandlerInterface {
  bool get shouldDelay => false;

  void showLoading();

  void dismissLoading();
}

abstract class FLXLoadingHandler implements FLXLoadingHandlerInterface {
  Future<T?> useLoading<T>(
    Future<T?> future, {
    bool? enable,
  }) =>
      useLoadingHandler(this, future, enable: enable);
}

Future<T?> useLoadingHandler<T>(
  FLXLoadingHandlerInterface handler,
  Future<T?> future, {
  bool? enable,
}) {
  enable ??= true;

  if (!enable) return future;

  if (handler.shouldDelay) {
    Future.delayed(Duration.zero, () {
      handler.showLoading();
    });
  } else {
    handler.showLoading();
  }

  future.whenComplete(() {
    handler.dismissLoading();
  });

  return future;
}

final FLXGlobalLoadingHandler globalLoadingHandler = FLXGlobalLoadingHandler();

class FLXGlobalLoadingHandler {
  static final FLXGlobalLoadingHandler _instance = FLXGlobalLoadingHandler._internal();

  FLXGlobalLoadingHandler._internal();

  factory FLXGlobalLoadingHandler() => _instance;

  FLXLoadingHandlerInterface normalHandler = FLXDefaultNormalLoadingHandler();
  FLXLoadingHandlerInterface clearHandler = FLXDefaultClearLoadingHandler();
}

class FLXDefaultNormalLoadingHandler implements FLXLoadingHandlerInterface {
  @override
  bool get shouldDelay => false;

  @override
  void dismissLoading() {
    // TODO: implement dismissLoading
  }

  @override
  void showLoading() {
    // TODO: implement showLoading
  }
}

class FLXDefaultClearLoadingHandler implements FLXLoadingHandlerInterface {
  @override
  bool get shouldDelay => false;

  @override
  void dismissLoading() {
    // TODO: implement dismissLoading
  }

  @override
  void showLoading() {
    // TODO: implement showLoading
  }
}
