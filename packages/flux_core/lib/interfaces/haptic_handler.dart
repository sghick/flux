import 'package:flutter/services.dart';

/// 触感反馈处理抽象接口
/// 核心包只定义接口，使用者通过 [hapticHandler] 注入具体实现
abstract class FLXHapticHandler {
  /// 轻触反馈
  void lightImpact();

  /// 中等力度反馈
  void mediumImpact();

  /// 重触反馈
  void heavyImpact();

  /// 选择反馈
  void selectionClick();
}

/// Haptic 全局单例代理
final FLXHapticHandler hapticHandler = FLXDefaultHapticHandler();

/// 默认 Haptic 实现 — 使用 Flutter 原生 HapticFeedback
class FLXDefaultHapticHandler implements FLXHapticHandler {
  @override
  void lightImpact() {
    HapticFeedback.lightImpact();
  }

  @override
  void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  @override
  void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  @override
  void selectionClick() {
    HapticFeedback.selectionClick();
  }
}