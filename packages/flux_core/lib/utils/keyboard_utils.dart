import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FLXKeyboard {
  static hideKeyboard([BuildContext? context]) {
    if (context != null) {
      unfocusPrimary(context);
    } else {
      unfocusGlobal();
    }
  }

  static unfocusGlobal() {
    WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
  }

  static unfocusPrimary(BuildContext context) {
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  static void unfocusPrimaryAll(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());
  }

  static bool isKeyboardShowing() {
    return WidgetsBinding.instance.focusManager.primaryFocus?.hasFocus ?? false;
  }

  void showKeyboard(FocusNode focusNode) {
    if (focusNode.hasFocus == false) {
      FocusScope.of(Get.context!).requestFocus(focusNode);
    }
  }
}
