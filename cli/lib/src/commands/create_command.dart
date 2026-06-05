import 'dart:io';

class CreateCommand {
  /// 获取 flux_gen 目录路径
  String get _fluxGenDir {
    final scriptPath = Platform.script.toFilePath();

    // 全局激活时: ~/.pub-cache/global_packages/flux/bin/xxx.snapshot
    // 需要找到 git 目录: ~/.pub-cache/git/flux-xxx/packages/flux_gen
    if (scriptPath.contains('.pub-cache/global_packages')) {
      // 向上查找 git 目录
      var dir = File(scriptPath).parent;
      for (int i = 0; i < 5; i++) {
        dir = dir.parent;
        if (dir.path.contains('.pub-cache/git/flux-')) {
          return '${dir.path}/packages/flux_gen';
        }
      }
      // fallback: 从 HOME 目录查找
      final homeGitFlux = '${Platform.environment['HOME']}/.pub-cache/git/flux-';
      final gitDir = Directory(Platform.environment['HOME']! + '/.pub-cache/git');
      if (gitDir.existsSync()) {
        for (final entry in gitDir.listSync()) {
          if (entry is Directory && entry.path.startsWith(homeGitFlux)) {
            return '${entry.path}/packages/flux_gen';
          }
        }
      }
    }

    // 本地开发时: 从脚本位置向上 3 级
    // cli/bin/flux.dart -> cli/ -> flux/ -> 仓库根
    final fluxRoot = File(scriptPath).parent.parent.parent.path;
    return '$fluxRoot/packages/flux_gen';
  }

  void execute({
    required String projectName,
    String? template,
    String? org,
    bool noExample = false,
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

    // Step 3: 创建项目结构
    print('📄 Creating project structure...');
    _createProjectStructure(projectDir.path);

    // Step 4: 复制 scripts
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

    // Step 6: 完成
    print('\n✅ Project "$projectName" created successfully!');
    print('\nNext steps:');
    print('  cd $projectName');
    print('  flutter run');
    print('');
    print('To customize the app, edit lib/main.dart');
  }

  void _createProjectStructure(String projectPath) {
    final libDir = Directory('$projectPath/lib');

    // consts
    Directory('${libDir.path}/consts').createSync();
    File('${libDir.path}/consts/strings.dart').writeAsStringSync('class AppStrings {}');
    File('${libDir.path}/consts/urls.dart').writeAsStringSync('class AppUrls {}');
    File('${libDir.path}/consts/events.dart').writeAsStringSync('class AppEvents {}');

    // main.dart
    _createMainFile('${libDir.path}/main.dart');
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

  void _setupScripts(String projectPath) {
    final scriptsDir = Directory('$projectPath/scripts');
    final scriptsPath = scriptsDir.path;
    scriptsDir.createSync(recursive: true);

    // 直接从 flux_gen 目录复制整个内容
    final sourceDir = _fluxGenDir;
    if (!Directory(sourceDir).existsSync()) {
      print('   Warning: flux_gen not found at $sourceDir');
      return;
    }

    print('   Copying flux_gen from: $sourceDir');

    // 复制所有文件和目录
    int copiedCount = 0;
    int skippedCount = 0;

    for (final entity in Directory(sourceDir).listSync(recursive: false)) {
      final name = entity.path.split('/').last;

      // 跳过隐藏文件
      if (name.startsWith('.')) continue;

      final destPath = '$scriptsPath/$name';
      final destFile = File(destPath);
      final destDir = Directory(destPath);

      if (entity is File) {
        if (destFile.existsSync()) {
          print('   Skipped: $name (already exists)');
          skippedCount++;
        } else {
          entity.copySync(destPath);
          print('   Copied: $name');
          copiedCount++;
        }
      } else if (entity is Directory) {
        _copyDirectoryRecursive(entity, destDir);
        print('   Copied: $name/');
        copiedCount++;
      }
    }

    print('   Summary: $copiedCount copied, $skippedCount skipped');
  }

  void _copyDirectoryRecursive(Directory source, Directory dest) {
    dest.createSync(recursive: true);
    for (final entity in source.listSync(recursive: false)) {
      final name = entity.path.split('/').last;
      if (name.startsWith('.')) continue;
      if (entity is File) {
        entity.copySync('${dest.path}/$name');
      } else if (entity is Directory) {
        _copyDirectoryRecursive(entity, Directory('${dest.path}/$name'));
      }
    }
  }
}
