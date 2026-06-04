import 'dart:io';

class UninstallCommand {
  void execute() {
    print('🗑️  Uninstalling Flux from this project...');

    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      print('Error: No pubspec.yaml found.');
      exit(1);
    }

    var content = pubspec.readAsStringSync();
    final lines = content.split('\n');
    final newLines = <String>[];
    bool skipFluxBlock = false;
    int indentLevel = 0;
    bool found = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (skipFluxBlock) {
        if (line.isEmpty) {
          skipFluxBlock = false;
          newLines.add(line);
          continue;
        }
        final currentIndent = line.indexOf(RegExp(r'\S'));
        if (currentIndent <= indentLevel) {
          skipFluxBlock = false;
          newLines.add(line);
        }
        continue;
      }

      // 检测 flux_core 依赖（支持 git、path 等方式）
      final trimmed = line.trim();
      if (trimmed == 'flux_core:' ||
          trimmed.startsWith('flux_core:') && !trimmed.startsWith('#')) {
        skipFluxBlock = true;
        indentLevel = line.indexOf(RegExp(r'\S'));
        found = true;
        print('   Removed: flux_core dependency');
        continue;
      }

      newLines.add(line);
    }

    if (!found) {
      print('   flux_core not found in pubspec.yaml');
    }

    // 写入更新后的内容
    pubspec.writeAsStringSync(newLines.join('\n'));

    // 询问是否删除项目结构
    print('');
    print('⚠️  Do you want to remove the project structure created by Flux?');
    print('   This will delete:');
    print('     - lib/config/');
    print('     - lib/consts/');
    print('     - lib/routes/');
    print('     - lib/ui/handlers/');
    print('     - scripts/');
    print('');
    print('   [y/N]: ',);

    final input = stdin.readLineSync()?.trim().toLowerCase();
    if (input == 'y' || input == 'yes') {
      _removeProjectStructure();
    } else {
      print('');
      print('   Skipped. To remove manually, run:');
      print('   rm -rf lib/config lib/consts lib/routes lib/ui scripts');
    }

    print('');
    print('✅ Flux uninstall completed!');
  }

  void _removeProjectStructure() {
    print('');
    print('   Removing project structure...');

    final dirsToRemove = [
      'lib/config',
      'lib/consts',
      'lib/routes',
      'lib/ui/handlers',
      'scripts',
    ];

    for (final dir in dirsToRemove) {
      final directory = Directory(dir);
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
        print('   Removed: $dir/');
      }
    }

    // 清理空的 lib/ui 目录
    final uiDir = Directory('lib/ui');
    if (uiDir.existsSync() && uiDir.listSync().isEmpty) {
      uiDir.deleteSync();
      print('   Removed: lib/ui/');
    }
  }
}
