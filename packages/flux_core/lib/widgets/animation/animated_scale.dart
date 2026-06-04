import 'package:flutter/material.dart';

class FLXAnimatedScale extends AnimatedWidget {
  final Widget child;

  const FLXAnimatedScale({
    super.key,
    required this.child,
    required Animation<double> animation,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = listenable as Animation<double>;
    return Transform.scale(scale: animation.value, child: child);
  }
}
