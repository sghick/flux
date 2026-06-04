import 'package:flutter/cupertino.dart';

class FLXBorderRadiusUtils {
  static BorderRadius except({
    Radius? topLeft,
    Radius? topRight,
    Radius? bottomLeft,
    Radius? bottomRight,
  }) {
    if (topLeft != null) {
      return BorderRadius.only(
        topRight: topLeft,
        bottomLeft: topLeft,
        bottomRight: topLeft,
      );
    }

    if (topRight != null) {
      return BorderRadius.only(
        topLeft: topRight,
        bottomLeft: topRight,
        bottomRight: topRight,
      );
    }

    if (bottomLeft != null) {
      return BorderRadius.only(
        topLeft: bottomLeft,
        topRight: bottomLeft,
        bottomRight: bottomLeft,
      );
    }

    if (bottomRight != null) {
      return BorderRadius.only(
        topLeft: bottomRight,
        topRight: bottomRight,
        bottomLeft: bottomRight,
      );
    }
    return BorderRadius.zero;
  }
}
