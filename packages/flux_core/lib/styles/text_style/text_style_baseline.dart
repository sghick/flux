import './text_style_builder.dart';
import 'package:flutter/material.dart';

extension TextStyleBaselineEx on TextStyleBuilder {
  TextStyleBuilder get alphabetic {
    return textBaseline(TextBaseline.alphabetic);
  }

  TextStyleBuilder get ideographic {
    return textBaseline(TextBaseline.ideographic);
  }
}
