import 'package:flutter/material.dart';

import 'loading_controller.dart';
import 'loading_handler.dart';
import 'loading_indicator.dart';

class FLXLoading extends StatefulWidget {
  final FLXLoadingController controller;
  final Widget? child;
  final Widget? loading;

  const FLXLoading({super.key, required this.controller, this.child, this.loading});

  @override
  State<StatefulWidget> createState() => _FLXLoadingState();
}

class _FLXLoadingState extends State<FLXLoading> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerStateChanged);
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(_controllerStateChanged);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [if (widget.child != null) widget.child!, _buildLoading()]);
  }

  Widget _buildLoading() {
    return Visibility(visible: widget.controller.show, child: widget.loading ?? _defaultLoading());
  }

  Widget _defaultLoading() => const FLXLoadingIndicator();

  void _controllerStateChanged() {
    setState(() {});
  }
}

mixin FLXUseLoadingMixin implements FLXLoadingHandlerInterface {
  final FLXLoadingController cbLoading = FLXLoadingController();

  FLXLoadingController get loadingController => cbLoading;

  @override
  bool get shouldDelay => false;

  @override
  void showLoading() => loadingController.showLoading();

  @override
  void dismissLoading() => loadingController.hideLoading();

  Future<T?> useLoading<T>(Future<T?> future, {bool? enable}) => useLoadingHandler(this, future, enable: enable);
}

Future<T?> useLoading<T>(Future<T?> future, {bool? enable}) => useLoadingHandler(globalLoadingHandler.normalHandler, future, enable: enable);

Future<T?> useClearLoading<T>(Future<T?> future, {bool? enable}) => useLoadingHandler(globalLoadingHandler.clearHandler, future, enable: enable);
