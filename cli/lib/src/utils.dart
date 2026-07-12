import 'dart:io';

/// 向上查找 pubspec.yaml，定位 CLI 包根目录，返回打包的 flux_gen 路径
String findFluxGenDir() {
  var dir = Directory(File(Platform.script.toFilePath()).parent.path);

  for (int i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      final pkgRoot = dir.path;
      return '$pkgRoot/lib/src/flux_gen';
    }
    dir = dir.parent;
  }

  throw StateError('Cannot locate flux CLI package root (pubspec.yaml not found). '
      'Please reinstall: dart pub global activate --source git https://github.com/sghick/flux.git');
}
