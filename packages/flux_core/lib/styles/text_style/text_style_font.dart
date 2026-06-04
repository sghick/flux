import './text_style_builder.dart';
import 'package:flutter/material.dart';

extension FLXTextStyleBuilderFontEx on TextStyleBuilder {
  TextStyleBuilder get wThin => w100;

  TextStyleBuilder get wLeastThick => w100;

  TextStyleBuilder get wExtraLight => w200;

  TextStyleBuilder get wLight => w300;

  TextStyleBuilder get wNormal => w400;

  TextStyleBuilder get wRegular => w400;

  TextStyleBuilder get wPlain => w400;

  TextStyleBuilder get wMedium => w500;

  TextStyleBuilder get wSemiBold => w600;

  TextStyleBuilder get wBold => w700;

  TextStyleBuilder get wExtraBold => w800;

  TextStyleBuilder get wBlack => w900;

  TextStyleBuilder get wMostThick => w900;

  /// w100 - w900
  TextStyleBuilder get w100 {
    return weight(FontWeight.w100);
  }

  TextStyleBuilder get w200 {
    return weight(FontWeight.w200);
  }

  TextStyleBuilder get w300 {
    return weight(FontWeight.w300);
  }

  TextStyleBuilder get w400 {
    return weight(FontWeight.w400);
  }

  TextStyleBuilder get w500 {
    return weight(FontWeight.w500);
  }

  TextStyleBuilder get w600 {
    return weight(FontWeight.w600);
  }

  TextStyleBuilder get w700 {
    return weight(FontWeight.w700);
  }

  TextStyleBuilder get w800 {
    return weight(FontWeight.w800);
  }

  TextStyleBuilder get w900 {
    return weight(FontWeight.w900);
  }
}
