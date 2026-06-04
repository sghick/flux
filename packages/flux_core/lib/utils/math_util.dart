import 'dart:math';
import 'dart:ui';

class FLXMathUtil {
  static num calculateAddition(String expression) {
    if (!expression.contains('+')) return 0;
    var cmp = expression.split('+');
    num a = num.parse(cmp.first);
    num b = num.parse(cmp.last);
    return a + b;
  }

  static double radianOByPoints(
    Offset o,
    Offset a,
    Offset b,
  ) {
    var voa = o - a;
    var vob = o - b;
    var vab = a - b;
    var oa = voa.distance;
    var ob = vob.distance;
    var ab = vab.distance;
    var cosO = (pow(oa, 2) + pow(ob, 2) - pow(ab, 2)) / (2 * oa * ob);
    var radianO = acos(cosO);
    var direction = 1;
    if (a.dx < o.dx) {
      // 左半
      if (vab.dy > 0) {
        // 向上
        direction = 1;
      } else {
        // 向下
        direction = -1;
      }
    } else {
      // 右半
      if (vab.dy > 0) {
        // 向下
        direction = -1;
      } else {
        // 向上
        direction = 1;
      }
    }
    return radianO * direction;
  }
}

extension FLXMathUtilsEx on num {
  double get toRadian => this * pi / 180;

  double get toAngle => this * 180 / pi;
}
