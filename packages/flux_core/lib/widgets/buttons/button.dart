import 'package:flutter/material.dart';

class FLXButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget? child;
  final Color? color;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  // 可以是数值,可以是BorderRadius对象,数值表示BorderRadius.circular(radius)
  final dynamic borderRadius;
  final BoxShape? shape;
  final Border? border;
  final Color? borderColor;
  final double borderWidth;
  final DecorationImage? backgroundImage;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final Alignment? alignment;
  final double? maxWidth;
  final double? maxHeight;

  const FLXButton({
    super.key,
    this.child,
    this.onTap,
    this.color,
    this.margin,
    this.padding,
    this.borderRadius,
    this.shape,
    this.border,
    this.borderColor,
    this.borderWidth = 1.0,
    this.backgroundImage,
    this.gradient,
    this.boxShadow,
    this.width,
    this.height,
    this.alignment,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: coreContent());
  }

  Widget coreContent() {
    BoxDecoration? decoration;
    if (border != null || borderColor != null || borderRadius != null || backgroundImage != null || gradient != null) {
      final effectiveBorder = border ?? (borderColor != null ? Border.all(color: borderColor!, width: borderWidth) : null);

      final effectiveBorderRadius = shape == BoxShape.circle
          ? null
          : borderRadius is BorderRadius
          ? borderRadius
          : borderRadius is num
          ? BorderRadius.circular(borderRadius.toDouble())
          : null;

      decoration = BoxDecoration(
        color: color ?? (gradient == null ? Colors.transparent : null),
        border: effectiveBorder,
        shape: shape ?? BoxShape.rectangle,
        borderRadius: effectiveBorderRadius,
        image: backgroundImage,
        gradient: gradient,
        boxShadow: boxShadow,
      );
    }

    BoxConstraints? constraints;
    if (maxHeight != null || maxWidth != null) {
      constraints = BoxConstraints(minWidth: 0, minHeight: 0, maxWidth: maxWidth ?? double.infinity, maxHeight: maxHeight ?? double.infinity);
    }

    return Container(
      color: decoration == null ? (color ?? Colors.transparent) : null,
      decoration: decoration,
      constraints: constraints,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      alignment: alignment,
      child: child,
    );
  }
}
