import 'package:flutter/material.dart';

class FLXLoadingController extends ChangeNotifier {
  bool _show = false;

  bool get show => _show;

  void showLoading() {
    _show = true;
    notifyListeners();
  }

  void hideLoading() {
    _show = false;
    notifyListeners();
  }
}
