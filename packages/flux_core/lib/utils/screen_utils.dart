import 'package:flutter_screenutil/flutter_screenutil.dart';

extension FLXScreenUtilExtension on num {
  double get dp => ScreenUtil().setWidth(this);

  ///[ScreenUtil.setWidth]
  double get w => ScreenUtil().setWidth(this);

  ///[ScreenUtil.setHeight]
  double get h => ScreenUtil().setHeight(this);

  ///[ScreenUtil.setSp]
  double get sp => ScreenUtil().setSp(this);

  ///屏幕宽度的倍数
  ///Multiple of screen width
  double get sw => ScreenUtil().screenWidth * this;

  ///屏幕高度的倍数
  ///Multiple of screen height
  double get sh => ScreenUtil().screenHeight * this;

  ///将设备原生DP 换算成像素 PX
  int get toPx {
    return (ScreenUtil().pixelRatio ?? 0 * this).toInt();
  }
}
