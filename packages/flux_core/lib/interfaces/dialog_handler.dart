import 'package:flutter/material.dart';

/// Dialog 操作按钮
class FLXDialogAction {
  final String text;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const FLXDialogAction(this.text, {this.onPressed, this.isDestructive = false});
}

/// Dialog 处理抽象接口
/// 核心包只定义接口，使用者通过 [dialogHandler] 注入具体实现
abstract class FLXDialogHandler {
  /// 显示 Alert 对话框
  Future<T?> showAlert<T>({
    String? title,
    String? message,
    Widget? content,
    List<FLXDialogAction> actions = const [],
    bool barrierDismissible = true,
  });

  /// 显示底部 Sheet
  Future<T?> showSheet<T>({
    required Widget builder,
    bool barrierDismissible = true,
  });
}

/// Dialog 全局单例代理
final FLXDialogHandler dialogHandler = FLXDefaultDialogHandler();

/// 默认 Dialog 实现 — 使用 Flutter 原生 Dialog
class FLXDefaultDialogHandler implements FLXDialogHandler {
  @override
  Future<T?> showAlert<T>({
    String? title,
    String? message,
    Widget? content,
    List<FLXDialogAction> actions = const [],
    bool barrierDismissible = true,
  }) {
    // 默认实现：不做任何 UI 展示
    debugPrint('[FLXDialog] alert: title=$title, message=$message');
    return Future.value(null);
  }

  @override
  Future<T?> showSheet<T>({
    required Widget builder,
    bool barrierDismissible = true,
  }) {
    debugPrint('[FLXDialog] sheet');
    return Future.value(null);
  }
}