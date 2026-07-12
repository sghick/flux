import 'dart:io';

/// 获取 flux_gen 目录路径（已打包在 CLI 的 lib/src/flux_gen/ 中）
String findFluxGenDir() {
  final scriptPath = Platform.script.toFilePath();
  // bin/ 和 lib/ 是同级目录：bin/flux.dart -> ../lib/src/flux_gen/
  final pkgRoot = File(scriptPath).parent.parent.path;
  return '$pkgRoot/lib/src/flux_gen';
}
