import 'package:flutter/material.dart';

import '../../styles/text_style/text_style_builder.dart';
import 'button.dart';


class FLXText extends FLXButton {
  final TextAlign? textAlign;
  final String? text;
  final dynamic style;
  final TextOverflow overflow;
  final int? maxLines;

  FLXText(
    this.text, {
    super.key,
    super.height,
    super.width,
    super.alignment,
    super.margin,
    super.backgroundImage,
    super.border,
    super.borderColor,
    super.borderRadius = 0,
    super.borderWidth = 1,
    super.shape,
    super.gradient,
    super.boxShadow,
    super.onTap,
    super.maxWidth,
    super.maxHeight,
    super.padding,
    super.color,
    this.style,
    this.textAlign = TextAlign.center,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines,
  }) : assert(style == null || style is TextStyle || style is TextStyleBuilder),
       super(
         child: Text(text ?? '', style: TextStyleBuilder.buildStyle(style), textAlign: textAlign, overflow: overflow, maxLines: maxLines),
       );
}
