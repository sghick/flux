import 'package:flux_core/interfaces/dialog_handler.dart';
import 'package:flutter/material.dart';

class AppDialogHandler implements FLXDialogHandler {
  @override
  Future<T?> showAlert<T>({
    String? title,
    String? message,
    Widget? content,
    List<FLXDialogAction> actions = const [],
    bool barrierDismissible = true,
  }) {
    debugPrint('[AppDialog] alert: title=$title');
    return Future.value(null);
  }

  @override
  Future<T?> showSheet<T>({
    required Widget builder,
    bool barrierDismissible = true,
  }) {
    debugPrint('[AppDialog] sheet');
    return Future.value(null);
  }
}