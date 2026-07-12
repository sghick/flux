import 'dart:io';
import '../utils.dart';

class GenCommand {

  void execute() {
    print('🔧 Installing Flux code generators...');

    final scriptsDir = Directory('scripts');
    if (scriptsDir.existsSync()) {
      print('✅ scripts/ directory already exists');
    } else {
      scriptsDir.createSync();
      print('   Created: scripts/');
    }

    final sourceDir = findFluxGenDir();
    if (!Directory(sourceDir).existsSync()) {
      print('Error: flux_gen not found at $sourceDir');
      print('Make sure Flux CLI is installed correctly.');
      exit(1);
    }
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
