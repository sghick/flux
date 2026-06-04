import 'package:get/get.dart';
import 'route_config.dart';

final nav = FLXNavigator();

class FLXNavigator {
  Future<T?> goWebPage<T>(String url, {String title = ''}) =>
      Get.toNamed<T>(RoutePath.pathWeb, arguments: {FLXParams.url: url, FLXParams.title: title});
}