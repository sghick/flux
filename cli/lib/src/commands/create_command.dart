import 'dart:io';
import '../utils.dart';

class CreateCommand {

  void execute({
    required String projectName,
    String? org,
  }) {
    print('🚀 Creating Flux project: $projectName');
    final projectDir = Directory(projectName);

    // Step 1: flutter create
    print('📦 Running flutter create...');
    final createArgs = <String>['create', projectName];
    if (org != null && org.isNotEmpty) {
      createArgs.addAll(['--org', org]);
    }
    final result = Process.runSync('flutter', createArgs);
    if (result.exitCode != 0) {
      print('Error: flutter create failed');
      print(result.stderr);
      exit(1);
    }
    print('   flutter create done.');

    // Step 2: 添加 flux_core 依赖
    print('🔧 Adding flux_core dependency...');
    final pubspecPath = '${projectDir.path}/pubspec.yaml';
    var pubspec = File(pubspecPath).readAsStringSync();
    if (!pubspec.contains('flux_core')) {
      pubspec = pubspec.replaceFirst(
        'dependencies:',
        'dependencies:\n  flux_core:\n    git:\n      url: https://github.com/sghick/flux.git\n      path: packages/flux_core\n',
      );
      File(pubspecPath).writeAsStringSync(pubspec);
    }

    // Step 3: 创建完整项目结构
    print('📄 Creating project structure...');
    _createProjectStructure(projectDir.path);

    // Step 4: 复制代码生成器
    _setupScripts(projectDir.path);

    // Step 5: flutter pub get
    print('📦 Running flutter pub get...');
    final pubGetResult = Process.runSync(
      'flutter',
      ['pub', 'get'],
      workingDirectory: projectDir.path,
    );
    if (pubGetResult.exitCode != 0) {
      print('Warning: flutter pub get had issues:');
      print(pubGetResult.stderr);
    }

    print('\n✅ Project "$projectName" created successfully!');
    print('\nNext steps:');
    print('  cd $projectName');
    print('  flutter run');
  }

  // ---- 项目结构 ----

  void _createProjectStructure(String projectPath) {
    final libDir = Directory('$projectPath/lib');

    // 覆盖 main.dart
    _createMainFile('${libDir.path}/main.dart');

    // 目录结构（合并自 init 的完整结构）
    final dirs = [
      'lib/config',
      'lib/consts',
      'lib/routes',
    ];
    for (final dir in dirs) {
      Directory('$projectPath/$dir').createSync(recursive: true);
    }

    // 模板文件
    _writeFile('$projectPath/lib/config/config.dart', _configTemplate());
    _writeFile('$projectPath/lib/consts/strings.dart', 'class AppStrings {}');
    _writeFile('$projectPath/lib/consts/urls.dart', 'class AppUrls {}');
    _writeFile('$projectPath/lib/consts/events.dart', 'class AppEvents {}');
    _writeFile('$projectPath/lib/routes/route_config.dart', _routeConfigTemplate());
    _writeFile('$projectPath/lib/routes/route_config.path.dart', _routePathTemplate());
    _writeFile('$projectPath/lib/routes/route_config.pages.dart', _routePagesTemplate());
    _writeFile('$projectPath/lib/routes/page_params.dart', _pageParamsTemplate());
    _writeFile('$projectPath/lib/routes/route_navigator.dart', _routeNavigatorTemplate());
  }

  void _writeFile(String path, String content) {
    File(path).writeAsStringSync(content);
  }

  void _createMainFile(String mainPath) {
    File(mainPath).writeAsStringSync('''
import 'package:flux_core/flux_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  App().start();
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        ScreenUtil.init(context, designSize: const Size(375, 667));
        return MediaQuery(
          data: MediaQuery.of(context),
          child: child ?? const SizedBox(),
        );
      },
    );
  }

  void start() {
    runApp(this);
  }
}
''');
  }

  // ---- 代码生成器 ----

  void _setupScripts(String projectPath) {
    final scriptsDir = Directory('$projectPath/scripts');
    final scriptsPath = scriptsDir.path;
    scriptsDir.createSync(recursive: true);

    final sourceDir = findFluxGenDir();
    if (!Directory(sourceDir).existsSync()) {
      print('   Warning: flux_gen not found at $sourceDir');
      return;
    }

    print('   Copying flux_gen from: $sourceDir');

    int copiedCount = 0;
    int skippedCount = 0;

    for (final entity in Directory(sourceDir).listSync(recursive: false)) {
      final name = entity.path.split('/').last;
      if (name.startsWith('.')) continue;

      final destPath = '$scriptsPath/$name';
      final destFile = File(destPath);
      final destDir = Directory(destPath);

      if (entity is File) {
        if (destFile.existsSync()) {
          skippedCount++;
        } else {
          entity.copySync(destPath);
          copiedCount++;
        }
      } else if (entity is Directory) {
        _copyDir(entity, destDir);
        copiedCount++;
      }
    }

    print('   Summary: $copiedCount copied, $skippedCount skipped');
  }

  void _copyDir(Directory source, Directory dest) {
    dest.createSync(recursive: true);
    for (final entity in source.listSync(recursive: false)) {
      final name = entity.path.split('/').last;
      if (name.startsWith('.')) continue;
      if (entity is File) {
        entity.copySync('${dest.path}/$name');
      } else if (entity is Directory) {
        _copyDir(entity, Directory('${dest.path}/$name'));
      }
    }
  }

  // ---- 模板内容 ----

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
