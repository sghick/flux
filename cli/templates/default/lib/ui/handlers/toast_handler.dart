import 'package:flux_core/interfaces/toast_handler.dart';
import 'package:flutter/material.dart';

class AppToastHandler implements FLXToastHandler {
  @override
  void show(String message, {FLXToastType type = FLXToastType.info, Duration? duration}) {
    // Replace with your preferred toast implementation
    debugPrint('[AppToast] $type: $message');
  }
}