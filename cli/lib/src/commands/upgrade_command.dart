import 'dart:io';

class UpgradeCommand {
  void execute() {
    print('🔄 Upgrading Flux packages...');

    // 检查 pubspec.yaml
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      print('Error: No pubspec.yaml found. Run this command in a Flutter project.');
      exit(1);
    }

    // flutter pub upgrade
    print('📦 Running flutter pub upgrade...');
    final result = Process.runSync('flutter', ['pub', 'upgrade', 'flux_core']);
    if (result.exitCode != 0) {
      print('Warning: flutter pub upgrade had issues:');
      print(result.stderr);
    } else {
      print('✅ Flux upgraded successfully!');
    }

    // 检查新版本
    print('');
    print('💡 To update CLI globally:');
    print('   dart pub global activate --source git https://github.com/sghick/flux.git');
  }
}