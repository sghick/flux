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

  /// 同一 apiId 允许多少个 caller 排队等待，超出则直接拒绝。
  /// 防止极端情况下（如页面快速重建）积压过多无意义的等待者。
  static int maxCallersPerApi = 5;

  /// 当前进行中的请求
  /// key: apiId, value: 该请求对应的 pending 状态
  final Map<String, _PendingState> _pendingRequests = {};

  /// 请求去重
  ///
  /// [apiId] 请求唯一标识，不允许为空
  /// [factory] 真正发起请求的工厂函数
  /// [onResult] 请求成功后，通知后续合并进来的 caller（结果回调）
  /// [onSendProgress] 请求过程中，转发发送进度给后续 caller
  /// [onReceiveProgress] 请求过程中，转发接收进度给后续 caller
  ///
  /// 如果当前没有相同 apiId 的请求在进行中，执行 factory 并返回结果；
  /// 如果已有相同 apiId 的请求在进行中，挂起当前请求，等待第一个请求的结果。
  Future<T> deduplicate<T>(
    String apiId,
    Future<T> Function() factory, {
    void Function(T result)? onResult,
    void Function(int count, int total)? onSendProgress,
    void Function(int count, int total)? onReceiveProgress,
  }) async {
    assert(apiId.isNotEmpty, 'apiId must not be empty');

    // 已有进行中的请求，注册到队列等待
    if (_pendingRequests.containsKey(apiId)) {
      final state = _pendingRequests[apiId]! as _PendingState<T>;
      final completer = Completer<T>();
      final caller = _CallerHandlers<T>(
        completer: completer,
        onResult: onResult,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      if (!state.tryEnqueue(caller)) {
        throw StateError(
          'Too many concurrent callers waiting for apiId: $apiId '
          '(max: $maxCallersPerApi). Consider using a different apiId.',
        );
      }
      return completer.future;
    }

    // 第一个请求：创建 PendingState 并执行
    final state = _PendingState<T>();
    _pendingRequests[apiId] = state;

    try {
      final result = await factory();
      // 成功：通知所有等待者（complete future + 回调 onResult）
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

  /// 包装发送进度回调：同时触发原始回调，并实时转发给所有排队中的 caller。
  ///
  /// 使用场景：第一个 caller 在其 factory 中将 Dio 的进度回调通过此方法包装，
  /// 这样后续排队的 caller 也能收到实时进度。
  void Function(int count, int total)? wrapSendProgress(
    String apiId,
    void Function(int count, int total)? original,
  ) {
    return (count, total) {
      original?.call(count, total);
      _pendingRequests[apiId]?.forwardSendProgress(count, total);
    };
  }

  /// 包装接收进度回调：同时触发原始回调，并实时转发给所有排队中的 caller。
  void Function(int count, int total)? wrapReceiveProgress(
    String apiId,
    void Function(int count, int total)? original,
  ) {
    return (count, total) {
      original?.call(count, total);
      _pendingRequests[apiId]?.forwardReceiveProgress(count, total);
    };
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

/// 单个排队 caller 的所有回调处理器，统一封装避免多份列表各自管理。
class _CallerHandlers<T> {
  final Completer<T> completer;
  final void Function(T result)? onResult;
  final void Function(int count, int total)? onSendProgress;
  final void Function(int count, int total)? onReceiveProgress;

  _CallerHandlers({
    required this.completer,
    this.onResult,
    this.onSendProgress,
    this.onReceiveProgress,
  });
}

/// 请求进行中的状态，管理一组排队等待的 caller。
///
/// 注意：第一个 caller 不在队列中——它的回调由 factory 内部直接触发；
/// 此处只管理后续合并进来的 caller。
class _PendingState<T> {
  final List<_CallerHandlers<T>> _callers = [];

  /// 尝试将 caller 加入排队队列。
  /// 返回 true 表示成功；返回 false 表示队列已满（达到 [FLXApiDeduplicator.maxCallersPerApi]）。
  bool tryEnqueue(_CallerHandlers<T> caller) {
    if (_callers.length >= FLXApiDeduplicator.maxCallersPerApi) return false;
    _callers.add(caller);
    return true;
  }

  /// 请求成功：完成所有等待者的 Future 并触发各自的 onResult
  void completeAll(T result) {
    for (final caller in _callers) {
      caller.completer.complete(result);
      caller.onResult?.call(result);
    }
  }

  /// 请求失败：通知所有等待者异常
  void completeAllError(Object error, StackTrace stackTrace) {
    for (final caller in _callers) {
      caller.completer.completeError(error, stackTrace);
    }
  }

  /// 实时转发发送进度给所有排队 caller
  void forwardSendProgress(int count, int total) {
    for (final caller in _callers) {
      caller.onSendProgress?.call(count, total);
    }
  }

  /// 实时转发接收进度给所有排队 caller
  void forwardReceiveProgress(int count, int total) {
    for (final caller in _callers) {
      caller.onReceiveProgress?.call(count, total);
    }
  }
}
