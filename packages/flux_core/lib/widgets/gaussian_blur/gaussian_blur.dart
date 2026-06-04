import 'dart:ui';

import 'package:flutter/material.dart';

class FLXGaussianBlur extends StatelessWidget {
  final Widget? blur;
  final Widget? child;

  const FLXGaussianBlur({super.key, this.blur, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (blur != null) blur!,
        BackdropFilter(filter: ImageFilter.blur(sigmaX: 41, sigmaY: 41), child: const SizedBox(width: 1, height: 1)),
        if (child != null) child!,
      ],
    );
  }
}
