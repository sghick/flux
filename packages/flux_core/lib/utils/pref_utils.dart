import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? _sharedPref;

SharedPreferences get sharedPref {
  if (_sharedPref == null) {
    throw Exception('请调用 initSharedPref 初始化, 或者等待其初始化完成');
  }
  return _sharedPref!;
}

Future<SharedPreferences> initSharedPref() async {
  _sharedPref = await SharedPreferences.getInstance();
  return Future.value(_sharedPref);
}

Future<SharedPreferences> get safeSharedPref async {
  return initSharedPref();
}
