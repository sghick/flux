import 'package:flux_core/styles/text_style/text_style_builder.dart';
import 'package:flutter/material.dart';

extension TextStyleBuilderColorExt on TextStyleBuilder {
  /// 0x00000000
  TextStyleBuilder get transparent => color(Colors.transparent);

  /// 0xFF000000
  TextStyleBuilder get black => color(Colors.black);

  /// 0xFFFFFFFF
  TextStyleBuilder get white => color(Colors.white);

  /// 0xFFF44336
  TextStyleBuilder get red => color(Colors.red);

  /// 0xFFFF5252
  TextStyleBuilder get redAccent => color(Colors.redAccent);

  /// 0xFFE91E63
  TextStyleBuilder get pink => color(Colors.pink);

  /// 0xFFFF4081
  TextStyleBuilder get pinkAccent => color(Colors.pinkAccent);

  /// 0xFF9C27B0
  TextStyleBuilder get purple => color(Colors.purple);

  /// 0xFFE040FB
  TextStyleBuilder get purpleAccent => color(Colors.purpleAccent);

  /// 0xFF673AB7
  TextStyleBuilder get deepPurple => color(Colors.deepPurple);

  /// 0xFF7C4DFF
  TextStyleBuilder get deepPurpleAccent => color(Colors.deepPurpleAccent);

  /// 0xFF3F51B5
  TextStyleBuilder get indigo => color(Colors.indigo);

  /// 0xFF536DFE
  TextStyleBuilder get indigoAccent => color(Colors.indigoAccent);

  /// 0xFF2196F3
  TextStyleBuilder get blue => color(Colors.blue);

  /// 0xFF448AFF
  TextStyleBuilder get blueAccent => color(Colors.blueAccent);

  /// 0xFF03A9F4
  TextStyleBuilder get lightBlue => color(Colors.lightBlue);

  /// 0xFF40C4FF
  TextStyleBuilder get lightBlueAccent => color(Colors.lightBlueAccent);

  /// 0xFF00BCD4
  TextStyleBuilder get cyan => color(Colors.cyan);

  /// 0xFF18FFFF
  TextStyleBuilder get cyanAccent => color(Colors.cyanAccent);

  /// 0xFF009688
  TextStyleBuilder get teal => color(Colors.teal);

  /// 0xFF64FFDA
  TextStyleBuilder get tealAccent => color(Colors.tealAccent);

  /// 0xFF4CAF50
  TextStyleBuilder get green => color(Colors.green);

  /// 0xFF69F0AE
  TextStyleBuilder get greenAccent => color(Colors.greenAccent);

  /// 0xFF8BC34A
  TextStyleBuilder get lightGreen => color(Colors.lightGreen);

  /// 0xFFB2FF59
  TextStyleBuilder get lightGreenAccent => color(Colors.lightGreenAccent);

  /// 0xFFCDDC39
  TextStyleBuilder get lime => color(Colors.lime);

  /// 0xFFEEFF41
  TextStyleBuilder get limeAccent => color(Colors.limeAccent);

  /// 0xFFFFEB3B
  TextStyleBuilder get yellow => color(Colors.yellow);

  /// 0xFFFFFF00
  TextStyleBuilder get yellowAccent => color(Colors.yellowAccent);

  /// 0xFFFFC107
  TextStyleBuilder get amber => color(Colors.amber);

  /// 0xFFFFD740
  TextStyleBuilder get amberAccent => color(Colors.amberAccent);

  /// 0xFFFF9800
  TextStyleBuilder get orange => color(Colors.orange);

  /// 0xFFFFAB40
  TextStyleBuilder get orangeAccent => color(Colors.orangeAccent);

  /// 0xFFFF5722
  TextStyleBuilder get deepOrange => color(Colors.deepOrange);

  /// 0xFFFF6E40
  TextStyleBuilder get deepOrangeAccent => color(Colors.deepOrangeAccent);

  /// 0xFF795548
  TextStyleBuilder get brown => color(Colors.brown);

  /// 0xFF9E9E9E
  TextStyleBuilder get grey => color(Colors.grey);

  /// 0xFF607D8B
  TextStyleBuilder get blueGrey => color(Colors.blueGrey);
}
