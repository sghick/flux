import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'api_options.dart';

/// 请求节流器（单例）
///
/// 同一时间多个相同 ApiId 的请求，只会真正发起一次网络请求，
/// 其余请求会被挂起，等结果返回后再分发给所有等待者。
///
/// 使用方式：
/// ```dart
/// final deduplicator = FLXApiDeduplicator();
/// final result = await deduplicator.deduplicate<T>(apiId, () => doRequest());
/// ```
class FLXApiDeduplicator {
  static final FLXApiDeduplicator _instance = FLXApiDeduplicator._internal();

  factory FLXApiDeduplicator() => _instance;

  FLXApiDeduplicator._internal();

  /// 当前进行中的请求
  /// key: apiId, value: 该请求对应的 pending 状态
  final Map<String, _PendingState> _pendingRequests = {};

  /// 请求去重
  ///
  /// [apiId] 请求唯一标识，不允许为空
  /// [factory] 真正发起请求的工厂函数
  ///
  /// 如果当前没有相同 apiId 的请求在进行中，执行 factory 并返回结果；
  /// 如果已有相同 apiId 的请求在进行中，挂起当前请求，等待第一个请求的结果。
  Future<T> deduplicate<T>(String apiId, Future<T> Function() factory) async {
    assert(apiId.isNotEmpty, 'apiId must not be empty');

    // 已有进行中的请求，注册一个 Completer 并等待
    if (_pendingRequests.containsKey(apiId)) {
      final state = _pendingRequests[apiId]!;
      final completer = Completer<T>();
      state.addCompleter(completer);
      return completer.future;
    }

    // 第一个请求：创建 PendingState 并执行
    final state = _PendingState<T>();
    _pendingRequests[apiId] = state;

    try {
      final result = await factory();
      // 成功：通知所有等待者
      state.completeAll(result);
      return result;
    } catch (e, s) {
      // 失败：通知所有等待者异常
      state.completeAllError(e, s);
      return Future.error(e, s);
    } finally {
      // 请求完成后立即清理
      _pendingRequests.remove(apiId);
    }
  }

  /// 是否有进行中的请求
  bool hasPending(String apiId) => _pendingRequests.containsKey(apiId);

  /// 当前进行中的请求数量
  int get pendingCount => _pendingRequests.length;

  /// 默认 ApiId 生成器
  ///
  /// 基于 method + url + params + data 生成 MD5 标识
  static String defaultApiIdGenerator(FLXApiOptions options) {
    final buffer = StringBuffer();
    buffer.write(options.method.value);
    buffer.write('_');
    buffer.write(options.fullUrl);
    buffer.write('_');
    buffer.write(options.params?.toString() ?? '');
    buffer.write('_');
    buffer.write(options.data?.toString() ?? '');
    return md5.convert(utf8.encode(buffer.toString())).toString();
  }
}

/// 请求进行中的状态，管理一组等待者
class _PendingState<T> {
  final List<Completer<T>> _completers = [];

  void addCompleter(Completer<T> completer) {
    _completers.add(completer);
  }

  void completeAll(T result) {
    for (final c in _completers) {
      c.complete(result);
    }
  }

  void completeAllError(Object error, StackTrace stackTrace) {
    for (final c in _completers) {
      c.completeError(error, stackTrace);
    }
  }
}
