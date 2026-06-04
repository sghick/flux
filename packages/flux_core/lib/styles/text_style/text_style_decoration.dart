import './text_style_builder.dart';
import 'package:flutter/material.dart';

extension FLXTextStyleDecorationExtention on TextStyleBuilder {
  TextStyleBuilder get decorationNone {
    return decoration(TextDecoration.none);
  }

  TextStyleBuilder get underline {
    return decoration(TextDecoration.underline);
  }

  TextStyleBuilder get overline {
    return decoration(TextDecoration.overline);
  }

  TextStyleBuilder get lineThrough {
    return decoration(TextDecoration.lineThrough);
  }
}
