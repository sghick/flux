import 'dart:io';

/// 获取 flux_gen 目录路径
String findFluxGenDir() {
  final scriptPath = Platform.script.toFilePath();

  // 全局激活时: ~/.pub-cache/global_packages/flux/bin/xxx.snapshot
  // 向上查找 git 缓存目录
  if (scriptPath.contains('.pub-cache/global_packages')) {
    var dir = File(scriptPath).parent;
    for (int i = 0; i < 5; i++) {
      dir = dir.parent;
      if (dir.path.contains('.pub-cache/git/flux-')) {
        return '${dir.path}/packages/flux_gen';
      }
    }
    // fallback: 从 HOME 目录查找
    final gitDir = Directory('${Platform.environment['HOME']}/.pub-cache/git');
    if (gitDir.existsSync()) {
      for (final entry in gitDir.listSync()) {
        if (entry is Directory && entry.path.contains('flux-')) {
          return '${entry.path}/packages/flux_gen';
        }
      }
    }
  }

  // 本地开发时: cli/bin/flux.dart -> flux/ -> 仓库根
  final fluxRoot = File(scriptPath).parent.parent.parent.path;
  return '$fluxRoot/packages/flux_gen';
}
