import 'package:flutter/material.dart';
import 'package:flux_core/widgets/loading/loading_handler.dart';

class AppNormalLoadingHandler implements FLXLoadingHandlerInterface {
  @override
  bool get shouldDelay => false;

  @override
  void showLoading() {
    // TODO: Show your loading indicator
  }

  @override
  void dismissLoading() {
    // TODO: Hide your loading indicator
  }
}

class AppClearLoadingHandler implements FLXLoadingHandlerInterface {
  @override
  bool get shouldDelay => false;

  @override
  void showLoading() {
    // TODO: Show your clear-style loading indicator
  }

  @override
  void dismissLoading() {
    // TODO: Hide your loading indicator
  }
}