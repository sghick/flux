#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import '../lib/src/commands/create_command.dart';
import '../lib/src/commands/gen_command.dart';

String getVersion() {
  final scriptPath = Platform.script.toFilePath();
  final parentDir = File(scriptPath).parent.path;
  final parentParentDir = File(scriptPath).parent.parent.path;

  final candidates = [
    '$parentParentDir/pubspec.yaml',
    '$parentDir/pubspec.yaml',
    '$parentDir/packages/flux/cli/pubspec.yaml',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;
      return yaml['version'] ?? '0.0.0';
    }
  }

  final gitCacheDir = Platform.environment['PUB_CACHE']
      ?? '${Platform.environment['HOME']}/.pub-cache';
  final gitFluxDir = Directory('$gitCacheDir/git')
      .listSync()
      .whereType<Directory>()
      .firstWhere(
        (d) => d.path.contains('flux-'),
        orElse: () => Directory(''),
      );

  if (gitFluxDir.path.isNotEmpty) {
    final pubspec = File('${gitFluxDir.path}/cli/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;
      return yaml['version'] ?? '0.0.0';
    }
  }

  return '0.0.0';
}

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addCommand('create', ArgParser()
      ..addOption('org', help: 'Organization (e.g., com.example)')
    )
    ..addCommand('gen', ArgParser())
    ..addFlag('version', abbr: 'v', help: 'Print version', defaultsTo: false);

  final results = parser.parse(arguments);

  if (results.command == null || results['version'] as bool) {
    final version = getVersion();
    print('Flux CLI v$version');
    print('');
    print('Usage: flux <command> [arguments]');
    print('');
    print('Commands:');
    print('  create    Create a new Flutter project with Flux framework');
    print('  gen       Install/update code generators (gen_pages, gen_api)');
    print('');
    print('Run "flux help <command>" for more information.');
    return;
  }

  switch (results.command!.name) {
    case 'create':
      final args = results.command!;
      final positionalArgs = args.rest;
      if (positionalArgs.isEmpty) {
        print('Error: Missing project name.');
        print('Usage: flux create <project_name> [--org com.example]');
        exit(1);
      }
      CreateCommand().execute(
        projectName: positionalArgs[0],
        org: args['org'] as String?,
      );
      break;
    case 'gen':
      GenCommand().execute();
      break;
    default:
      print('Unknown command: ${results.command!.name}');
      print('Available commands: create, gen');
      exit(1);
  }
}
