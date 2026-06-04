import 'dart:io';

class InitCommand {
  void execute({bool bare = false}) {
    print('🔧 Initializing Flux in existing project...');
    
    // Check if pubspec.yaml exists
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('Error: pubspec.yaml not found. Are you in a Flutter project directory?');
      exit(1);
    }

    // Step 1: Add flux_core dependency
    print('\n📦 Adding flux_core dependency...');
    var pubspec = pubspecFile.readAsStringSync();
    if (!pubspec.contains('flux_core')) {
      pubspec = pubspec.replaceFirst(
        'dependencies:',
        'dependencies:\n  flux_core:\n    path: ../packages/flux_core\n',
      );
      pubspecFile.writeAsStringSync(pubspec);
    } else {
      print('   flux_core dependency already exists, skipping.');
    }

    if (bare) {
      print('   Done (bare mode). Run flutter pub get to install.');
      return;
    }

    // Step 2: Create directory structure
    print('\n📄 Creating project structure (existing files will be skipped)...');
    _createStructure();

    // Step 3: Run pub get
    print('\n📦 Running flutter pub get...');
    final result = Process.runSync('flutter', ['pub', 'get']);
    if (result.exitCode != 0) {
      print('Warning: flutter pub get had issues:');
      print(result.stderr);
    }

    print('\n✅ Flux has been initialized successfully!');
    print('\nNext steps:');
    print('  1. Edit lib/config/config.dart with your app settings');
    print('  2. Create your UI handler implementations in lib/ui/handlers/');
    print('  3. Register handlers in main.dart');
    print('  4. Run flutter run');
  }

  void _createStructure() {
    final dirs = [
      'lib/config',
      'lib/consts',
      'lib/routes',
      'lib/ui/handlers',
      'scripts',
    ];

    for (final dir in dirs) {
      final d = Directory(dir);
      if (!d.existsSync()) {
        d.createSync(recursive: true);
        print('   Created: $dir/');
      } else {
        print('   Exists:  $dir/');
      }
    }

    // Create sample config if not exists
    _createIfNotExists('lib/config/config.dart', _configTemplate());
    _createIfNotExists('lib/consts/strings.dart', 'class AppStrings {}');
    _createIfNotExists('lib/consts/urls.dart', 'class AppUrls {}');
    _createIfNotExists('lib/consts/events.dart', 'class AppEvents {}');
    _createIfNotExists('lib/routes/route_config.dart', _routeConfigTemplate());
    _createIfNotExists('lib/routes/route_config.path.dart', _routePathTemplate());
    _createIfNotExists('lib/routes/route_config.pages.dart', _routePagesTemplate());
    _createIfNotExists('lib/routes/page_params.dart', _pageParamsTemplate());
    _createIfNotExists('lib/routes/route_navigator.dart', _routeNavigatorTemplate());
  }

  void _createIfNotExists(String path, String content) {
    final file = File(path);
    if (!file.existsSync()) {
      file.writeAsStringSync(content);
      print('   Created: $path');
    } else {
      print('   Skipped: $path (already exists)');
    }
  }

  String _configTemplate() => '''
class AppConfig {
  final String host;
  final String appName;

  const AppConfig({
    this.host = 'http://localhost:8080',
    this.appName = 'my_app',
  });

  static const AppConfig current = AppConfig();
}
''';

  String _routeConfigTemplate() => '''
import 'package:get/get.dart';

part 'route_config.pages.dart';
part 'route_config.path.dart';

class RouteConfig {
  static final List<GetPage> getPages = RoutePages.getPages;
}
''';

  String _routePathTemplate() => '''
class RoutePath {
  static const String pathSplash = '/auth/splash';
  static const String pathWeb = '/others/web';
}
''';

  String _routePagesTemplate() => '''
import 'package:get/get.dart';

part of 'route_config.dart';

class RoutePages {
  static final List<GetPage> getPages = [];
}
''';

  String _pageParamsTemplate() => '''
class FLXParams {
  static const String url = 'url';
  static const String title = 'title';
}
''';

  String _routeNavigatorTemplate() => '''
import 'package:get/get.dart';
import 'route_config.dart';

final nav = FLXNavigator();

class FLXNavigator {
  Future<T?> goWebPage<T>(String url, {String title = ''}) =>
      Get.toNamed<T>(RoutePath.pathWeb, arguments: {FLXParams.url: url, FLXParams.title: title});
}
''';
}