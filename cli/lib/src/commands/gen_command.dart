import 'dart:io';

class GenCommand {
  /// Flux 仓库根目录
  String get _fluxRoot {
    return File(Platform.script.toFilePath()).parent.parent.parent.path;
  }

  /// 获取 flux_gen 脚本源路径
  String get _genSourceDir {
    final cliRoot = File(Platform.script.toFilePath()).parent.parent.path;

    // 全局激活时
    if (Directory('$cliRoot/scripts').existsSync()) {
      return '$cliRoot/scripts';
    }
    // 本地开发时
    if (Directory('$_fluxRoot/packages/flux_gen').existsSync()) {
      return '$_fluxRoot/packages/flux_gen';
    }
    return '$cliRoot/scripts';
  }

  void execute() {
    print('🔧 Installing Flux code generators...');

    final scriptsDir = Directory('scripts');
    if (scriptsDir.existsSync()) {
      print('✅ scripts/ directory already exists');
    } else {
      scriptsDir.createSync();
      print('   Created: scripts/');
    }

    final sourceDir = _genSourceDir;
    print('   Source: $sourceDir');

    // 复制生成器脚本
    final genFiles = [
      'gen_pages.py',
      'gen_api.py',
      'gen_pages.sh',
      'gen_api.sh',
      'gen_page_config.json',
    ];

    for (final name in genFiles) {
      final src = '$sourceDir/$name';
      if (File(src).existsSync()) {
        File(src).copySync('scripts/$name');
        print('   Created: scripts/$name');
      }
    }

    // 复制 templates
    final templateSrc = Directory('$sourceDir/templates');
    if (templateSrc.existsSync()) {
      _copyDirectory(templateSrc, Directory('scripts/templates'));
      print('   Created: scripts/templates/');
    }

    // 复制 api_conf
    final apiConfSrc = Directory('$sourceDir/api_conf');
    if (apiConfSrc.existsSync()) {
      _copyDirectory(apiConfSrc, Directory('scripts/api_conf'));
      print('   Created: scripts/api_conf/');
    }

    print('');
    print('✅ Flux generators installed!');
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
}
