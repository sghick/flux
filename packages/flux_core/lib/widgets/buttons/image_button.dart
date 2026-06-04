import 'package:flutter/cupertino.dart';

import 'button.dart';

class FLXImageButton extends FLXButton {
  FLXImageButton(
    dynamic image, {
    super.key,
    super.onTap,
    super.color,
    super.margin,
    super.padding,
    super.borderRadius,
    super.shape,
    super.border,
    super.borderColor,
    super.borderWidth = 1.0,
    super.backgroundImage,
    super.gradient,
    super.boxShadow,
    super.width,
    super.height,
    super.alignment,
    double? imageWidth,
    double? imageHeight,
    Color? imageColor,
    BoxFit fit = BoxFit.contain,
  }) : super(
         child: (image is String) ? Image.asset(image, width: imageWidth, height: imageHeight, fit: fit, color: imageColor) : image,
       );
}
