import 'package:flutter/material.dart';

typedef FLXAnimationWidgetBuilder = Widget Function(
  BuildContext context,
  Widget? child,
  Animation animation,
  AnimationController controller,
);

typedef FLXAnimationEndCallback = void Function(
    Animation animation, AnimationController controller);

class FLXLAnimationBuilder extends StatefulWidget {
  final Duration duration;
  final bool repeat;
  final Widget? child;
  final FLXAnimationWidgetBuilder builder;
  final FLXAnimationEndCallback? onEnd;

  const FLXLAnimationBuilder({
    super.key,
    this.duration = const Duration(milliseconds: 300),
    this.repeat = false,
    this.child,
    required this.builder,
    this.onEnd,
  });

  @override
  State<StatefulWidget> createState() => _FLXLAnimationBuilderState();
}

class _FLXLAnimationBuilderState extends State<FLXLAnimationBuilder>
    with TickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    animation = Tween<double>(begin: 0, end: 1).animate(controller);
    controller.forward();
    if (widget.repeat) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) {
        if (animation.isCompleted || animation.isDismissed) {
          widget.onEnd?.call(animation, controller);
        }
        return widget.builder(context, child, animation, controller);
      },
    );
  }
}
