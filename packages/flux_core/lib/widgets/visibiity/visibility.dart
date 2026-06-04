import 'package:flutter/cupertino.dart';

class FLXVisibility extends StatelessWidget {
  final bool visible;
  final WidgetBuilder builder;
  final bool placeIfHide;

  const FLXVisibility({
    super.key,
    required this.visible,
    required this.builder,
    this.placeIfHide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Visibility(
      maintainAnimation: placeIfHide,
      maintainSize: placeIfHide,
      maintainState: placeIfHide,
      visible: visible,
      child: visible ? builder(context) : Container(),
    );
  }
}

class FLXAnimatedVisibility extends StatelessWidget {
  final bool visible;
  final WidgetBuilder builder;
  final bool placeIfHide;
  final TransitionBuilder animationBuilder;

  const FLXAnimatedVisibility({
    super.key,
    required this.visible,
    required this.builder,
    this.placeIfHide = false,
    required this.animationBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return animationBuilder(
      context,
      visible ? builder(context) : Container(),
    );
  }

  static FLXAnimatedVisibility switcher({
    required bool visible,
    required WidgetBuilder builder,
    bool placeIfHide = false,
    Duration duration = const Duration(milliseconds: 300),
  }) =>
      FLXAnimatedVisibility(
        visible: visible,
        builder: builder,
        placeIfHide: placeIfHide,
        animationBuilder: (context, child) =>
            AnimatedSwitcher(duration: duration, child: child),
      );

  static FLXAnimatedVisibility scale({
    required bool visible,
    required WidgetBuilder builder,
    bool placeIfHide = false,
    Duration duration = const Duration(milliseconds: 300),
  }) =>
      FLXAnimatedVisibility(
        visible: visible,
        builder: builder,
        placeIfHide: placeIfHide,
        animationBuilder: (context, child) => AnimatedScale(
            scale: visible ? 1 : 0, duration: duration, child: child),
      );

  static FLXAnimatedVisibility opacity({
    required bool visible,
    required WidgetBuilder builder,
    bool placeIfHide = false,
    Duration duration = const Duration(milliseconds: 300),
  }) =>
      FLXAnimatedVisibility(
        visible: visible,
        builder: builder,
        placeIfHide: placeIfHide,
        animationBuilder: (context, child) => AnimatedOpacity(
            opacity: visible ? 1 : 0, duration: duration, child: child),
      );
}
