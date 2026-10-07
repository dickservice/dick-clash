import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'desktop/model.dart';
import 'interface.dart';
import 'method.dart';

class CoreLib extends CoreHandlerInterface {
  static CoreLib? _instance;

  final Service? _service;

  Completer<bool> _connectedCompleter = Completer<bool>();
  Future<CoreLifecycleResult>? _closeOperation;
  Future<CoreLifecycleResult>? _startOperation;
  Future<void> _operationTail = Future<void>.value();
  int _connectionGeneration = 0;
  int? _startGeneration;
  bool _initialized = false;
  int _lifecycleRevision = 0;
  int _methodCallId = 0;
  bool _closed = false;

  CoreLib._internal() : _service = service;

  @visibleForTesting
  CoreLib.scoped(Service this._service);

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  factory CoreLib() {
    _instance ??= CoreLib._internal();
    return _instance!;
  }

  @override
  Future<CoreLifecycleResult> start() async {
    if (_closed) {
      throw StateError('Core lifecycle is closed');
    }
    final revision = ++_lifecycleRevision;
    final generation = _connectionGeneration;
    final pending = _startOperation;
    if (pending != null && _startGeneration == generation) {
      final result = await pending;
      return CoreLifecycleResult(
        revision: revision,
        outcome:
            !_isCurrent(generation) ||
                result.outcome == CoreLifecycleOutcome.superseded
            ? CoreLifecycleOutcome.superseded
            : CoreLifecycleOutcome.coalesced,
      );
    }
    if (_connectedCompleter.isCompleted) {
      return CoreLifecycleResult(
        revision: revision,
        outcome: CoreLifecycleOutcome.coalesced,
      );
    }
    final connection = _connectedCompleter;
    final operation = _serialize(
      () => _start(revision, generation, connection),
    );
    _startOperation = operation;
    _startGeneration = generation;
    try {
      return await operation;
    } finally {
      if (identical(_startOperation, operation)) {
        _startOperation = null;
        _startGeneration = null;
      }
    }
  }

  bool _isCurrent(int generation) =>
      !_closed && generation == _connectionGeneration;

  CoreLifecycleResult _superseded(int revision) => CoreLifecycleResult(
    revision: revision,
    outcome: CoreLifecycleOutcome.superseded,
  );

  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _operationTail.then((_) => action());
    _operationTail = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<CoreLifecycleResult> _start(
    int revision,
    int generation,
    Completer<bool> connection,
  ) async {
    if (!_isCurrent(generation)) {
      return _superseded(revision);
    }
    try {
      final initializationError = await _service?.init() ?? '';
      if (initializationError.isEmpty) {
        _initialized = true;
      }
      if (!_isCurrent(generation)) {
        return _superseded(revision);
      }
      if (initializationError.isNotEmpty) {
        throw StateError(initializationError);
      }
      connection.complete(true);
      final syncError =
          await _service?.syncState(
            globalState.container.read(sharedStateProvider),
          ) ??
          '';
      if (!_isCurrent(generation)) {
        return _superseded(revision);
      }
      if (syncError.isNotEmpty) {
        _connectedCompleter = Completer<bool>();
        _initialized = false;
        await _service?.shutdown();
        throw StateError(syncError);
      }
    } catch (_) {
      if (!_isCurrent(generation)) {
        return _superseded(revision);
      }
      rethrow;
    }
    return CoreLifecycleResult(
      revision: revision,
      outcome: CoreLifecycleOutcome.applied,
    );
  }

  @override
  Future<CoreLifecycleResult> restart() async {
    final result = await stop();
    if (_closed || result.outcome == CoreLifecycleOutcome.superseded) {
      return _superseded(result.revision);
    }
    return start();
  }

  @override
  Future<CoreLifecycleResult> stop() => _stop();

  Future<CoreLifecycleResult> _stop({bool allowClosed = false}) async {
    if (_closed && !allowClosed) {
      throw StateError('Core lifecycle is closed');
    }
    final revision = ++_lifecycleRevision;
    final generation = ++_connectionGeneration;
    final connection = _connectedCompleter;
    _connectedCompleter = Completer<bool>();
    if (!connection.isCompleted) {
      connection.complete(false);
    }
    return _serialize(() async {
      if (!_initialized) {
        return CoreLifecycleResult(
          revision: revision,
          outcome: generation == _connectionGeneration
              ? CoreLifecycleOutcome.coalesced
              : CoreLifecycleOutcome.superseded,
        );
      }
      _initialized = false;
      final stopped = await _service?.shutdown() ?? true;
      if (generation != _connectionGeneration) {
        return _superseded(revision);
      }
      if (!stopped) {
        throw StateError('Android Core service shutdown failed');
      }
      return CoreLifecycleResult(
        revision: revision,
        outcome: CoreLifecycleOutcome.applied,
      );
    });
  }

  @override
  Future<CoreLifecycleResult> close() {
    return _closeOperation ??= _close();
  }

  Future<CoreLifecycleResult> _close() async {
    _closed = true;
    return _stop(allowClosed: true);
  }

  @override
  Future<bool> startListener() async {
    final listenerStarted = await super.startListener();
    final serviceStarted = await _service?.start() ?? false;
    return listenerStarted && serviceStarted;
  }

  @override
  Future<bool> stopListener() async {
    final serviceStopped = await _service?.stop() ?? false;
    final listenerStopped = await super.stopListener();
    return serviceStopped && listenerStopped;
  }

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) {
    return _invokeMethod<T>(
      method: method,
      arguments: arguments,
    ).withTimeout(timeout: timeout, onTimeout: () => null);
  }

  Future<T?> _invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
  }) async {
    if (_closed) {
      return null;
    }
    final connection = _connectedCompleter;
    try {
      final connected = await connection.future.timeout(
        coreConnectionWaitDuration,
      );
      if (!connected ||
          _closed ||
          !identical(connection, _connectedCompleter)) {
        return null;
      }
    } catch (error) {
      commonPrint.log(
        'Invoke method ${method.name} before connection timed out: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
    final id = '${++_methodCallId}';
    final response = await _service?.invokeMethod(
      CoreMethodCall(id: id, method: method, arguments: arguments),
    );
    if (response == null) {
      return null;
    }
    return response.unwrap<T>();
  }
}

CoreLib? get coreLib => system.isAndroid ? CoreLib() : null;
