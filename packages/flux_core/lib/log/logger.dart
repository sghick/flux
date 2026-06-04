import 'dart:convert';
import 'dart:isolate';

import 'package:logger/logger.dart';

Logger? _logger;
LoggerConfig _config = LoggerConfig();

Logger get logger {
  if (_logger != null) {
    return _logger!;
  }
  _logger = Logger(
      printer: FLXCustomPrinter(config: _config),
      filter: ProductionFilter(),
      level: isDevMode ? _config.debugLogLevel : _config.releaseLogLevel);

  return _logger!;
}

void loggerInit(LoggerConfig config) {
  _config = config;
}

bool get isDevMode {
  bool devMode = false;
  assert(() {
    devMode = true;
    return true;
  }());
  return devMode;
}

void log(dynamic obj, [dynamic error, StackTrace? stackTrace]) {
  _log(Level.info, obj, error, stackTrace);
}

void logT(dynamic obj, [dynamic error, StackTrace? stackTrace]) {
  _log(Level.trace, obj, error, stackTrace);
}

void logW(dynamic obj, [dynamic error, StackTrace? stackTrace]) {
  _log(Level.warning, obj, error, stackTrace);
}

void logE(dynamic obj, [dynamic error, StackTrace? stackTrace]) {
  _log(Level.error, obj, error, stackTrace);
}

void logI(dynamic obj, [dynamic error, StackTrace? stackTrace]) {
  _log(Level.info, obj, error, stackTrace);
}

void logD(dynamic obj, [dynamic error, StackTrace? stackTrace]) {
  _log(Level.debug, obj, error, stackTrace);
}

void logO(dynamic obj, [dynamic error, StackTrace? stackTrace]) {
  _log(Level.off, obj, error, stackTrace);
}

void _log(Level level, dynamic obj, [dynamic error, StackTrace? stackTrace]) {
  if (Logger.level.index > level.index) return;
  if (obj is Function) {
    dynamic resObj;
    try {
      resObj = obj();
    } catch (e) {
      resObj = "traceLog crashed:$e";
    }
    obj = resObj;
  }
  logger.log(level, obj, error: error, stackTrace: stackTrace);
}

class FLXCustomPrinter extends LogPrinter {
  static final levelPrefixes = {
    Level.trace: 'trace ',
    Level.debug: 'debug',
    Level.info: 'info ',
    Level.warning: 'warn ',
    Level.error: 'error',
    Level.fatal: 'fatal  ',
    Level.off: 'off  ',
  };

  late bool showTime;
  late bool showIsolate;

  FLXCustomPrinter({LoggerConfig? config}) {
    showTime = config?.showTime ?? false;
    showIsolate = config?.showIsolate ?? false;
  }

  @override
  List<String> log(LogEvent event) {
    var timeStr = showTime ? ' [${DateTime.now().toIso8601String()}]' : '';
    var isolateName = showIsolate ? ' (${Isolate.current.debugName})' : '';
    var messageStr = _stringifyMessage(event.message);
    var errorStr = event.error != null ? ' ERROR: ${event.error}' : '';
    var stackStr =
        event.stackTrace != null ? ' STACK: ${event.stackTrace}' : '';
    return [
      '[${levelPrefixes[event.level]}]$timeStr$isolateName $messageStr$errorStr$stackStr'
    ];
  }

  String _stringifyMessage(dynamic message) {
    if (message is Map || message is Iterable) {
      var encoder = const JsonEncoder.withIndent(null);
      return encoder.convert(message);
    } else {
      return message.toString();
    }
  }
}

class LoggerConfig {
  final bool showTime;
  final bool showIsolate;
  final Level releaseLogLevel;
  final Level debugLogLevel;

  LoggerConfig({
    this.showTime = false,
    this.showIsolate = false,
    this.releaseLogLevel = Level.info,
    this.debugLogLevel = Level.trace,
  });
}
