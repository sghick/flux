import 'dart:io';

/// 标准化查找策略：定位 flux_gen 源目录
///
/// 查找顺序（与激活方式一一对应）：
/// 1. 包根 + lib/src/flux_gen/   （dart run / --source path）
/// 2. .pub-cache/git/flux-xxx    （--source git，每次激活一个目录，会堆积）
/// 3. .pub-cache/global_packages/flux/scripts/  （旧版兼容）
String findFluxGenDir() {
  final candidates = <String>[];

  // 策略 1: 向上查找包根（推荐方式，--source path 走这里）
  var dir = Directory(File(Platform.script.toFilePath()).parent.path);
  for (int i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      candidates.add('${dir.path}/lib/src/flux_gen');
      break;
    }
    dir = dir.parent;
  }

  // 策略 2: pub-cache git 目录（--source git 走这里，可能有多个 flux-xxx 目录）
  final pubCache = Platform.environment['PUB_CACHE']
      ?? '${Platform.environment['HOME']}/.pub-cache';
  final gitDir = Directory('$pubCache/git');
  if (gitDir.existsSync()) {
    // 按修改时间排序，最新的优先
    final fluxDirs = gitDir
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.contains(RegExp(r'flux-[\da-f]+$')))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    for (final d in fluxDirs) {
      candidates.add('${d.path}/packages/flux_gen');
    }
  }

  // 策略 3: 旧版兼容（global_packages/flux/scripts/）
  candidates.add('$pubCache/global_packages/flux/scripts');

  for (final c in candidates) {
    if (Directory(c).existsSync()) {
      return c;
    }
  }

  throw StateError(
      'Cannot locate flux_gen source. Tried:\n${candidates.map((c) => '  - $c').join('\n')}\n'
      'Please reinstall: dart pub global activate --source git https://github.com/sghick/flux.git');
}

/// 清理 .pub-cache/git/ 中残留的 flux-* 目录
int cleanFluxGitCache() {
  final pubCache = Platform.environment['PUB_CACHE']
      ?? '${Platform.environment['HOME']}/.pub-cache';
  final gitDir = Directory('$pubCache/git');
  if (!gitDir.existsSync()) return 0;

  final fluxDirs = gitDir
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.contains(RegExp(r'flux-[\da-f]+$')))
      .toList();

  int removed = 0;
  for (final d in fluxDirs) {
    final name = d.path.split('/').last;
    d.deleteSync(recursive: true);
    print('  🗑  removed: $name');
    removed++;
  }
  return removed;
}
