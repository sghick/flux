import 'package:flutter/material.dart';

class FLXAnimationBreathe extends StatefulWidget {
  final Widget? child;
  final double initScale;
  final double startScale;
  final double endScale;
  final Duration duration;
  final Duration intervalDuration;
  final Alignment alignment;
  final Curve curve;

  const FLXAnimationBreathe({
    super.key,
    this.initScale = 1.0,
    this.startScale = 0.95,
    this.endScale = 1.05,
    this.duration = const Duration(milliseconds: 500),
    this.intervalDuration = const Duration(milliseconds: 0),
    this.alignment = Alignment.center,
    this.curve = Curves.linear,
    this.child,
  });

  static FLXAnimationBreathe goods({
    double initScale = 1.0,
    double startScale = 0.95,
    double endScale = 1.05,
    Duration duration = const Duration(milliseconds: 600),
    Duration intervalDuration = const Duration(milliseconds: 0),
    Alignment alignment = Alignment.bottomCenter,
    Curve curve = Curves.linear,
    Widget? child,
  }) =>
      FLXAnimationBreathe(
        initScale: initScale,
        startScale: startScale,
        endScale: endScale,
        duration: duration,
        intervalDuration: intervalDuration,
        alignment: alignment,
        curve: curve,
        child: child,
      );

  static FLXAnimationBreathe animal({
    double initScale = 1.0,
    double startScale = 0.99,
    double endScale = 1.01,
    Duration duration = const Duration(milliseconds: 700),
    Duration intervalDuration = const Duration(milliseconds: 0),
    Alignment alignment = Alignment.bottomCenter,
    Curve curve = Curves.linear,
    Widget? child,
  }) =>
      FLXAnimationBreathe(
        initScale: initScale,
        startScale: startScale,
        endScale: endScale,
        duration: duration,
        intervalDuration: intervalDuration,
        alignment: alignment,
        curve: curve,
        child: child,
      );

  @override
  State<StatefulWidget> createState() => _FLXAnimationBreatheState();
}

class _FLXAnimationBreatheState extends State<FLXAnimationBreathe> {
  double scale = 1;
  bool reversed = false;

  @override
  void initState() {
    super.initState();
    scale = widget.initScale;
    Future(() {
      refreshScale();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: scale,
      duration: widget.duration,
      alignment: widget.alignment,
      curve: widget.curve,
      onEnd: () {
        if (reversed) {
          refreshScale();
        } else {
          Future.delayed(widget.intervalDuration)
              .then((value) => refreshScale());
        }
      },
      child: widget.child,
    );
  }

  void refreshScale() {
    setState(() {
      reversed = !reversed;
      scale = reversed ? widget.startScale : widget.endScale;
    });
  }
}
