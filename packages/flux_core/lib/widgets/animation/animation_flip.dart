import 'dart:math';

import 'package:flutter/material.dart';
import 'animation_builder.dart';


class FLXAnimationFlip extends StatefulWidget {
  final Widget? child;
  final double radius;
  final Curve curve;
  final Duration duration;
  final Axis direction;
  final Alignment alignment;
  final FLXAnimationEndCallback? onEnd;

  const FLXAnimationFlip({
    super.key,
    this.child,
    this.radius = 2 * pi,
    this.curve = Curves.ease,
    this.duration = const Duration(milliseconds: 300),
    this.direction = Axis.horizontal,
    this.alignment = Alignment.center,
    this.onEnd,
  });

  @override
  State<StatefulWidget> createState() => _FLXAnimationFlipState();
}

class _FLXAnimationFlipState extends State<FLXAnimationFlip> {
  @override
  Widget build(BuildContext context) {
    return FLXLAnimationBuilder(
      builder: (context, child, animation, controller) {
        if (animation.isCompleted) {
          widget.onEnd?.call(animation, controller);
        }
        var matrix = Matrix4.identity();
        matrix.setEntry(3, 2, 0.001);
        if (widget.direction == Axis.horizontal) {
          matrix.rotateY(animation.value * widget.radius);
        } else {
          matrix.rotateX(animation.value * widget.radius);
        }
        return Transform(
          alignment: widget.alignment,
          transform: matrix,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
