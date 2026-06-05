#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import '../lib/src/commands/create_command.dart';
import '../lib/src/commands/gen_command.dart';
import '../lib/src/commands/init_command.dart';
import '../lib/src/commands/uninstall_command.dart';
import '../lib/src/commands/upgrade_command.dart';

const String _cliDir = String.fromEnvironment('flux.cliDir', defaultValue: '');

String getVersion() {
  String? pubspecPath;

  if (_cliDir.isNotEmpty) {
    // 编译时传入的路径
    pubspecPath = '$_cliDir/pubspec.yaml';
  } else {
    // 开发时使用 Platform.script
    final scriptPath = Platform.script.toFilePath();
    if (scriptPath.endsWith('.dart')) {
      pubspecPath = '${File(scriptPath).parent.parent.path}/pubspec.yaml';
    } else {
      // 编译后的可执行文件，使用包目录
      pubspecPath = '${File(scriptPath).parent.path}/../pkg/flux/cli/pubspec.yaml';
    }
  }

  final pubspecFile = File(pubspecPath);
  if (!pubspecFile.existsSync()) {
    return '0.0.0';
  }
  final content = pubspecFile.readAsStringSync();
  final yaml = loadYaml(content) as YamlMap;
  return yaml['version'] ?? '0.0.0';
}

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addCommand('create', ArgParser()
      ..addOption('template', abbr: 't', help: 'Path to a custom project template')
      ..addOption('org', help: 'Organization (e.g., com.example)')
      ..addFlag('no-example', help: 'Skip example pages', defaultsTo: false)
    )
    ..addCommand('gen', ArgParser()
      ..addFlag('pages', help: 'Generate pages only', defaultsTo: false)
      ..addFlag('api', help: 'Generate API models only', defaultsTo: false)
    )
    ..addCommand('init', ArgParser()
      ..addFlag('bare', help: 'Only add dependencies, skip directory creation', defaultsTo: false)
    )
    ..addCommand('upgrade', ArgParser())
    ..addCommand('uninstall', ArgParser())
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
    print('  gen       Install code generators (gen_pages, gen_api)');
    print('  init      Integrate Flux into an existing Flutter project');
    print('  upgrade   Upgrade Flux packages in this project');
    print('  uninstall Remove Flux from this project');
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
        print('Usage: flux create <project_name> [--template path] [--org com.example]');
        exit(1);
      }
      CreateCommand().execute(
        projectName: positionalArgs[0],
        template: args['template'] as String?,
        org: args['org'] as String?,
        noExample: args['no-example'] as bool,
      );
      break;
    case 'gen':
      GenCommand().execute();
      break;
    case 'init':
      final args = results.command!;
      InitCommand().execute(
        bare: args['bare'] as bool,
      );
      break;
    case 'upgrade':
      UpgradeCommand().execute();
      break;
    case 'uninstall':
      UninstallCommand().execute();
      break;
    default:
      print('Unknown command: ${results.command!.name}');
      exit(1);
  }
}