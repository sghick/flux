import 'package:flutter/material.dart';
import 'animation_builder.dart';

class FLXAnimationTranslate extends StatefulWidget {
  final Widget? child;
  final Offset offset;
  final Duration duration;
  final Alignment alignment;
  final Curve curve;
  final bool transformHitTests;
  final FilterQuality? filterQuality;
  final FLXAnimationEndCallback? onEnd;
  final bool reversed;
  final bool repeat;

  const FLXAnimationTranslate({
    super.key,
    this.child,
    required this.offset,
    this.duration = const Duration(milliseconds: 300),
    this.alignment = Alignment.center,
    this.curve = Curves.ease,
    this.transformHitTests = true,
    this.filterQuality,
    this.onEnd,
    this.repeat = false,
    this.reversed = false,
  });

  @override
  State<StatefulWidget> createState() => _FLXAnimationTranslateState();
}

class _FLXAnimationTranslateState extends State<FLXAnimationTranslate>
    with SingleTickerProviderStateMixin {
  bool isForward = true;

  @override
  Widget build(BuildContext context) {
    return FLXLAnimationBuilder(
      duration: widget.duration,
      repeat: widget.reversed ? false : widget.repeat,
      onEnd: widget.reversed
          ? (animation, controller) {
              if (isForward) {
                controller.reverse();
                isForward = false;
              } else {
                if (widget.repeat) {
                  controller.forward();
                  isForward = true;
                } else {
                  widget.onEnd?.call(animation, controller);
                }
              }
            }
          : widget.onEnd,
      builder: (context, child, animation, controller) {
        Offset offset = Offset(
          widget.offset.dx * animation.value,
          widget.offset.dy * animation.value,
        );
        return Transform.translate(
          offset: offset,
          transformHitTests: widget.transformHitTests,
          filterQuality: widget.filterQuality,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
