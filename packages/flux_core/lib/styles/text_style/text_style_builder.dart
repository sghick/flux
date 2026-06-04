import 'package:flutter/material.dart';

import '../../utils/color_ext.dart';

class TextStyleBuilder {
  double? _size;
  Color? _color;
  FontWeight? _weight;
  double? _height;
  TextDecoration? _decoration;
  Color? _decorationColor;
  TextDecorationStyle? _decorationStyle;
  double? _decorationThickness;
  double? _letterSpacing;
  double? _wordSpacing;
  String? _fontFamily;
  TextBaseline? _textBaseline;

  TextStyleBuilder({
    double? size,
    Color? color,
    FontWeight? weight,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    double? letterSpacing,
    double? wordSpacing,
    String? fontFamily,
    TextBaseline? textBaseline,
  }) {
    _size = size;
    _color = color;
    _weight = weight;
    _height = height;
    _decoration = decoration;
    _decorationColor = decorationColor;
    _decorationStyle = decorationStyle;
    _decorationThickness = decorationThickness;
    _letterSpacing = letterSpacing;
    _wordSpacing = wordSpacing;
    _fontFamily = fontFamily;
    _textBaseline = textBaseline;
  }

  static TextStyle? buildStyle(dynamic style) {
    if (style is TextStyleBuilder) return style.build;
    if (style is TextStyle) return style;
    return null;
  }

  TextStyleBuilder size(double size) {
    _size = size;
    return this;
  }

  TextStyleBuilder color(dynamic color, [double opacity = 1]) {
    if (color is Color) {
      _color = color..withValues(alpha: opacity);
    } else if (color is int) {
      _color = Color(color)..withValues(alpha: opacity);
    } else if (color is String) {
      _color = FLXColorExt.hexString(color, opacity);
    }
    return this;
  }

  TextStyleBuilder alpha(double alpha) {
    _color = _color?.withValues(alpha: alpha);
    return this;
  }

  TextStyleBuilder weight(FontWeight weight) {
    _weight = weight;
    return this;
  }

  TextStyleBuilder height(double height) {
    _height = height;
    return this;
  }

  TextStyleBuilder decoration(TextDecoration decoration) {
    _decoration = decoration;
    return this;
  }

  TextStyleBuilder decorationColor(Color color) {
    _decorationColor = color;
    return this;
  }

  TextStyleBuilder decorationStyle(TextDecorationStyle decorationStyle) {
    _decorationStyle = decorationStyle;
    return this;
  }

  TextStyleBuilder decorationThickness(double decorationThickness) {
    _decorationThickness = decorationThickness;
    return this;
  }

  TextStyleBuilder letterSpacing(double letterSpacing) {
    _letterSpacing = letterSpacing;
    return this;
  }

  TextStyleBuilder wordSpacing(double wordSpacing) {
    _wordSpacing = wordSpacing;
    return this;
  }

  TextStyleBuilder fontFamily(String fontFamily) {
    _fontFamily = fontFamily;
    return this;
  }

  TextStyleBuilder textBaseline(TextBaseline textBaseline) {
    _textBaseline = textBaseline;
    return this;
  }

  TextStyle get build {
    return TextStyle(
      fontSize: _size,
      color: _color,
      fontWeight: _weight,
      height: _height,
      decoration: _decoration,
      decorationColor: _decorationColor ?? _defaultDecorationColor(),
      decorationStyle: _decorationStyle,
      decorationThickness: _decorationThickness,
      letterSpacing: _letterSpacing,
      wordSpacing: _wordSpacing,
      fontFamily: _fontFamily,
      textBaseline: _textBaseline,
    );
  }

  Color? _defaultDecorationColor() => (_decoration != null) ? _color : null;
}
