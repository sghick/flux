import 'package:flutter/material.dart';

enum FLXProgressAxis {
  leftToRight,
  rightToLeft,
  topToBottom,
  bottomToTop,
}

class FLXProgress extends StatelessWidget {
  final FLXProgressController controller;
  final double? width;
  final double? height;
  final Axis direction;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final dynamic borderRadius;
  final Alignment alignment;
  final Gradient? indicatorGradient;
  final Color? indicatorColor;
  final Border? indicatorBorder;
  final dynamic indicatorBorderRadius;

  const FLXProgress({
    super.key,
    required this.controller,
    this.width,
    this.height,
    this.direction = Axis.horizontal,
    this.color,
    this.gradient,
    this.border,
    this.borderRadius,
    this.alignment = Alignment.bottomLeft,
    this.indicatorGradient,
    this.indicatorColor = Colors.red,
    this.indicatorBorder,
    this.indicatorBorderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            border: border,
            gradient: gradient,
            borderRadius: _asBorderRadius(borderRadius),
          ),
          alignment: alignment,
          child: indicatorGradient == null
              ? _buildIndicator()
              : ShaderMask(
                  shaderCallback: (Rect bounds) =>
                      indicatorGradient!.createShader(bounds),
                  blendMode: BlendMode.srcATop,
                  child: _buildIndicator(),
                ),
        );
      },
    );
  }

  Widget _buildIndicator() {
    var borderRadius = _fixedIndicatorBorderRadius();
    return FractionallySizedBox(
      widthFactor: direction == Axis.horizontal ? controller.value : null,
      heightFactor: direction == Axis.vertical ? controller.value : null,
      child: Container(
        decoration: BoxDecoration(
          color: indicatorColor,
          borderRadius: _asBorderRadius(borderRadius),
          border: indicatorBorder,
        ),
      ),
    );
  }

  dynamic _fixedIndicatorBorderRadius() =>
      indicatorBorderRadius ?? borderRadius;

  dynamic _asBorderRadius(dynamic br) =>
      (br is num) ? BorderRadius.circular(br.toDouble()) : br;
}

class FLXProgressController extends ValueNotifier<double> {
  FLXProgressController(super.value) : assert(value >= 0 && value <= 1);
}

///
/// FLXProgressAnimatedBuilder
///

class FLXAnimatedProgressBuilder extends StatefulWidget {
  final FLXAnimatedProgressController controller;
  final TransitionBuilder builder;
  final Widget? child;

  const FLXAnimatedProgressBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.child,
  });

  @override
  State<FLXAnimatedProgressBuilder> createState() =>
      _LKAnimatedProgressBuilderState();
}

class _LKAnimatedProgressBuilderState extends State<FLXAnimatedProgressBuilder>
    with SingleTickerProviderStateMixin {
  late AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = widget.controller.animation ??
        AnimationController(duration: widget.controller.duration, vsync: this);
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        animation.reset();
        animation.forward();
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            widget.controller._animatedProgressRefresh(animation.value);
            return widget.builder(context, widget.child);
          },
          child: child,
        );
      },
    );
  }
}

class FLXAnimatedProgressController extends ValueNotifier<double> {
  final Duration duration;
  final AnimationController? animation;

  FLXAnimatedProgressController({
    double progress = 0,
    this.duration = const Duration(milliseconds: 300),
    this.animation,
  }) : super(progress);

  /// for animation
  double oldValue = 0;

  double _animatedProgress = 0;

  double get animatedProgress => _animatedProgress;

  void _animatedProgressRefresh(double p) => _animatedProgress = p * value;
}
