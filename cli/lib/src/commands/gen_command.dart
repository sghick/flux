import 'dart:io';
import '../utils.dart';

class GenCommand {
  void execute() {
    final sw = Stopwatch()..start();

    print('🔧 Flux Gen — Installing code generators');
    print('─────────────────────────────────────────');

    // 1. 诊断信息
    print('[info] platform.script: ${Platform.script}');

    final sourceDir = findFluxGenDir();
    final source = Directory(sourceDir);
    print('[info] resolved source: $sourceDir');
    print('[info] source exists:  ${source.existsSync()}');

    if (!source.existsSync()) {
      _err('flux_gen not found at $sourceDir');
      _err('Reinstall Flux CLI: dart pub global activate --source git https://github.com/sghick/flux.git');
      exit(1);
    }

    // 列出源目录内容
    final srcEntries = source.listSync();
    print('[info] source contents (${srcEntries.length} items):');
    for (final e in srcEntries) {
      final type = e is Directory ? 'dir ' : 'file';
      final name = e.path.split('/').last;
      print('         [$type] $name');
    }

    // 2. 目标目录
    final scriptsDir = Directory('scripts');
    if (scriptsDir.existsSync()) {
      print('[info] scripts/ already exists');
    } else {
      scriptsDir.createSync(recursive: true);
      print('[info] scripts/ created');
    }

    // 3. 复制脚本文件
    int copied = 0, skipped = 0, missing = 0;
    final genFiles = [
      'gen_pages.py',
      'gen_api.py',
      'gen_pages.sh',
      'gen_api.sh',
      'gen_page_config.json',
      'gen_config.json',
    ];

    print('');
    print('─ Copying script files ─');
    for (final name in genFiles) {
      final src = File('$sourceDir/$name');
      if (src.existsSync()) {
        src.copySync('scripts/$name');
        print('  ✓  scripts/$name');
        copied++;
      } else {
        print('  ✗  scripts/$name  (source missing: $sourceDir/$name)');
        missing++;
      }
    }

    // 4. 复制 templates
    print('');
    print('─ Copying templates/ ─');
    final templateSrc = Directory('$sourceDir/templates');
    if (templateSrc.existsSync()) {
      final tmplFiles = _countFiles(templateSrc);
      print('[info] templates source: ${templateSrc.path} ($tmplFiles files)');
      _copyDirectory(templateSrc, Directory('scripts/templates'));
      print('  ✓  scripts/templates/');
      copied++;
    } else {
      print('  ✗  templates/  (source missing: ${templateSrc.path})');
      missing++;
    }

    // 5. 复制 api_conf
    print('');
    print('─ Copying api_conf/ ─');
    final apiConfSrc = Directory('$sourceDir/api_conf');
    if (apiConfSrc.existsSync()) {
      final apiFiles = _countFiles(apiConfSrc);
      print('[info] api_conf source: ${apiConfSrc.path} ($apiFiles files)');
      _copyDirectory(apiConfSrc, Directory('scripts/api_conf'));
      print('  ✓  scripts/api_conf/');
      copied++;
    } else {
      print('  ✗  api_conf/  (source missing: ${apiConfSrc.path})');
      missing++;
    }

    // 6. 验证结果
    print('');
    print('─ Result ─');
    print('[info] copied: $copied, skipped: $skipped, missing: $missing');
    print('[info] elapsed: ${sw.elapsedMilliseconds}ms');

    final resultEntries = scriptsDir.listSync(recursive: true);
    print('[info] scripts/ contents (${resultEntries.length} items):');
    for (final e in resultEntries) {
      final type = e is Directory ? 'dir ' : 'file';
      final relative = e.path.replaceFirst('scripts/', '');
      print('         [$type] $relative');
    }

    print('');
    print('✅ Done!');
    print('');
    print('Usage:');
    print('  ./scripts/gen_pages.sh          # Generate page files');
    print('  ./scripts/gen_api.sh            # Generate API models');
  }

  void _copyDirectory(Directory source, Directory dest) {
    dest.createSync(recursive: true);
    for (final entity in source.listSync(recursive: false)) {
      final name = entity.path.split('/').last;
      if (name.startsWith('.')) continue;
      if (entity is File) {
        entity.copySync('${dest.path}/$name');
      } else if (entity is Directory) {
        _copyDirectory(entity, Directory('${dest.path}/$name'));
      }
    }
  }

  int _countFiles(Directory dir) {
    int count = 0;
    for (final e in dir.listSync(recursive: true)) {
      if (e is File) count++;
    }
    return count;
  }

  void _err(String msg) => print('❌ $msg');
}
