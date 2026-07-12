import '../utils.dart';

class CleanCommand {
  void execute() {
    print('🧹 Cleaning Flux CLI cache...');
    print('─────────────────────────────────────────');

    final removed = cleanFluxGitCache();
    if (removed == 0) {
      print('  (no leftover flux-xxx directories)');
    } else {
      print('');
      print('✅ Removed $removed cache director${removed == 1 ? 'y' : 'ies'}.');
    }
  }
}
