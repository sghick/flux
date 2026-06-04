import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// AppBar 主题处理抽象接口
/// 核心包只定义接口，使用者通过 [appBarThemeHandler] 注入具体实现
abstract class FLXAppBarThemeHandler {
  /// 获取当前 AppBar 主题
  AppBarTheme get appBarTheme;

  /// 获取当前状态栏样式
  SystemUiOverlayStyle get statusBarStyle;

  /// 应用状态栏样式
  void applyStyle();
}

/// AppBar 主题全局单例代理
final FLXAppBarThemeHandler appBarThemeHandler = FLXDefaultAppBarThemeHandler();

/// 默认 AppBar 主题实现 — 朴素 Flutter 默认
class FLXDefaultAppBarThemeHandler implements FLXAppBarThemeHandler {
  @override
  AppBarTheme get appBarTheme => const AppBarTheme(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      );

  @override
  SystemUiOverlayStyle get statusBarStyle => const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      );

  @override
  void applyStyle() {
    SystemChrome.setSystemUIOverlayStyle(statusBarStyle);
  }
}