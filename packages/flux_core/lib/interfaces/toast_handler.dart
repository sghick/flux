import 'package:flutter/material.dart';

/// Toast 类型
enum FLXToastType { info, success, warning, error }

/// Toast 处理抽象接口
/// 核心包只定义接口，使用者通过 [toastHandler] 注入具体实现
abstract class FLXToastHandler {
  /// 显示一条 Toast 消息
  void show(String message, {FLXToastType type = FLXToastType.info, Duration? duration});
}

/// Toast 全局单例代理
final FLXToastHandler toastHandler = FLXDefaultToastHandler();

/// 默认 Toast 实现 — 仅输出到控制台
class FLXDefaultToastHandler implements FLXToastHandler {
  @override
  void show(String message, {FLXToastType type = FLXToastType.info, Duration? duration}) {
    debugPrint('[FLXToast] $type: $message');
  }
}