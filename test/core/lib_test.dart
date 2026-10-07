import 'dart:async';

import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/lib.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_profiles.dart';

class _FakeService implements Service {
  _FakeService();

  final calls = <String>[];

  Completer<String>? pendingInit;
  Completer<String>? pendingSync;
  Completer<bool>? pendingShutdown;
  final syncStarted = Completer<void>();
  final shutdownStarted = Completer<void>();

  String initError = '';
  String syncError = '';
  bool shutdownResult = true;
  bool startResult = true;
  bool stopResult = true;
  CoreMethodResponse? Function(CoreMethodCall call)? onInvokeMethod;

  final invokedCalls = <CoreMethodCall>[];

  @override
  Future<String> init() async {
    calls.add('init');
    return await pendingInit?.future ?? initError;
  }

  @override
  Future<String> syncState(SharedState state) async {
    calls.add('syncState');
    if (!syncStarted.isCompleted) {
      syncStarted.complete();
    }
    return await pendingSync?.future ?? syncError;
  }

  @override
  Future<bool> shutdown() async {
    calls.add('shutdown');
    if (!shutdownStarted.isCompleted) {
      shutdownStarted.complete();
    }
    return await pendingShutdown?.future ?? shutdownResult;
  }

  @override
  Future<bool> start() async {
    calls.add('start');
    return startResult;
  }

  @override
  Future<bool> stop() async {
    calls.add('stop');
    return stopResult;
  }

  @override
  Future<CoreMethodResponse?> invokeMethod(CoreMethodCall call) async {
    calls.add('invokeMethod:${call.method.name}');
    invokedCalls.add(call);
    return onInvokeMethod?.call(call);
  }

  @override
  Future<DateTime?> getRunTime() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _FakeService service;
  late CoreLib lib;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    service = _FakeService();
    lib = CoreLib.scoped(service);
  });

  tearDown(() {
    container.dispose();
    CoreLib.resetInstance();
  });

  group('start', () {
    test('initializes, connects and syncs shared state', () async {
      final result = await lib.start();

      expect(result.outcome, CoreLifecycleOutcome.applied);
      expect(result.revision, 1);
      expect(service.calls, ['init', 'syncState']);
    });

    test('coalesces a second start while already connected', () async {
      await lib.start();
      service.calls.clear();

      final result = await lib.start();

      expect(result.outcome, CoreLifecycleOutcome.coalesced);
      expect(result.revision, 2);
      expect(service.calls, isEmpty);
    });

    test('coalesces starts pending initialization', () async {
      service.pendingInit = Completer<String>();
      final first = lib.start();
      final second = lib.start();
      await Future<void>.delayed(Duration.zero);

      expect(service.calls, ['init']);
      service.pendingInit!.complete('');
      final results = await Future.wait([first, second]);

      expect(results.map((result) => result.revision), [1, 2]);
      expect(results.map((result) => result.outcome), [
        CoreLifecycleOutcome.applied,
        CoreLifecycleOutcome.coalesced,
      ]);
      expect(service.calls, ['init', 'syncState']);
    });

    test('coalesces starts until shared state sync finishes', () async {
      service.pendingSync = Completer<String>();
      final first = lib.start();
      await service.syncStarted.future;
      var completed = false;
      final second = lib.start().then((result) {
        completed = true;
        return result;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      service.pendingSync!.complete('');
      expect((await first).outcome, CoreLifecycleOutcome.applied);
      expect((await second).outcome, CoreLifecycleOutcome.coalesced);
      expect(service.calls, ['init', 'syncState']);
    });

    test('pending starts share failure and can retry', () async {
      service.pendingInit = Completer<String>();
      final first = expectLater(lib.start(), throwsA(isA<StateError>()));
      final second = expectLater(lib.start(), throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      service.pendingInit!.complete('init boom');
      await Future.wait([first, second]);
      expect(service.calls, ['init']);

      service.pendingInit = null;
      expect((await lib.start()).outcome, CoreLifecycleOutcome.applied);
    });

    test('pending sync callers share failure and cleanup', () async {
      service.pendingSync = Completer<String>();
      final first = expectLater(lib.start(), throwsA(isA<StateError>()));
      await service.syncStarted.future;
      final second = expectLater(lib.start(), throwsA(isA<StateError>()));
      service.pendingSync!.complete('sync boom');
      await Future.wait([first, second]);
      expect(service.calls, ['init', 'syncState', 'shutdown']);

      service.pendingSync = null;
      expect((await lib.start()).outcome, CoreLifecycleOutcome.applied);
    });

    test('an initialization error leaves the handler unconnected', () async {
      service.initError = 'init boom';

      await expectLater(
        lib.start(),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'init boom'),
        ),
      );
      expect(service.calls, ['init']);

      service.initError = '';
      final retry = await lib.start();
      expect(retry.outcome, CoreLifecycleOutcome.applied);
    });

    test('a sync error shuts the service down and reopens the gate', () async {
      service.syncError = 'sync boom';

      await expectLater(
        lib.start(),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'sync boom'),
        ),
      );
      expect(service.calls, ['init', 'syncState', 'shutdown']);

      service.syncError = '';
      service.calls.clear();
      final retry = await lib.start();

      expect(retry.outcome, CoreLifecycleOutcome.applied);
      expect(service.calls, ['init', 'syncState']);
    });
  });

  group('stop', () {
    test('coalesces when there is nothing connected', () async {
      final result = await lib.stop();

      expect(result.outcome, CoreLifecycleOutcome.coalesced);
      expect(service.calls, isEmpty);
    });

    test('shuts the service down once connected', () async {
      await lib.start();
      service.calls.clear();

      final result = await lib.stop();

      expect(result.outcome, CoreLifecycleOutcome.applied);
      expect(service.calls, ['shutdown']);
    });

    test(
      'invalidates pending init and serializes a replacement start',
      () async {
        service.pendingInit = Completer<String>();
        final first = lib.start();
        await Future<void>.delayed(Duration.zero);
        final stopped = lib.stop();
        final replacement = lib.start();
        expect(service.calls, ['init']);

        service.pendingInit!.complete('');
        expect((await first).outcome, CoreLifecycleOutcome.superseded);
        expect((await stopped).outcome, CoreLifecycleOutcome.applied);
        expect((await replacement).outcome, CoreLifecycleOutcome.applied);
        expect(service.calls, ['init', 'shutdown', 'init', 'syncState']);
      },
    );

    test('a start waits for an in-flight shutdown', () async {
      await lib.start();
      service.calls.clear();
      service.pendingShutdown = Completer<bool>();
      final stopped = lib.stop();
      await service.shutdownStarted.future;
      final started = lib.start();
      await Future<void>.delayed(Duration.zero);
      expect(service.calls, ['shutdown']);

      service.pendingShutdown!.complete(true);
      expect((await stopped).outcome, CoreLifecycleOutcome.applied);
      expect((await started).outcome, CoreLifecycleOutcome.applied);
      expect(service.calls, ['shutdown', 'init', 'syncState']);
    });

    test('supersedes delayed sync without duplicate error cleanup', () async {
      service.pendingSync = Completer<String>();
      final started = lib.start();
      await service.syncStarted.future;
      final stopped = lib.stop();
      service.pendingSync!.complete('obsolete sync error');

      expect((await started).outcome, CoreLifecycleOutcome.superseded);
      expect((await stopped).outcome, CoreLifecycleOutcome.applied);
      expect(service.calls, ['init', 'syncState', 'shutdown']);
    });

    test('a failed shutdown throws but still closes the gate', () async {
      await lib.start();
      service.shutdownResult = false;

      await expectLater(lib.stop(), throwsA(isA<StateError>()));

      service.shutdownResult = true;
      final again = await lib.stop();
      expect(again.outcome, CoreLifecycleOutcome.coalesced);
    });
  });

  test('restart stops before starting again', () async {
    await lib.start();
    service.calls.clear();

    final result = await lib.restart();

    expect(result.outcome, CoreLifecycleOutcome.applied);
    expect(service.calls, ['shutdown', 'init', 'syncState']);
  });

  group('close', () {
    test('is terminal and rejects later lifecycle intents', () async {
      await lib.start();

      final result = await lib.close();
      expect(result.outcome, CoreLifecycleOutcome.applied);

      await expectLater(lib.start(), throwsA(isA<StateError>()));
      await expectLater(lib.stop(), throwsA(isA<StateError>()));
    });

    test('prevents queued initialization after immediate close', () async {
      final started = lib.start();
      final closed = lib.close();

      expect((await started).outcome, CoreLifecycleOutcome.superseded);
      expect((await closed).outcome, CoreLifecycleOutcome.coalesced);
      expect(service.calls, isEmpty);
    });

    test('invalidates delayed init and all coalesced starts', () async {
      service.pendingInit = Completer<String>();
      final first = lib.start();
      final second = lib.start();
      await Future<void>.delayed(Duration.zero);
      final closed = lib.close();
      service.pendingInit!.complete('');

      expect((await first).outcome, CoreLifecycleOutcome.superseded);
      expect((await second).outcome, CoreLifecycleOutcome.superseded);
      expect((await closed).outcome, CoreLifecycleOutcome.applied);
      expect(service.calls, ['init', 'shutdown']);
      await expectLater(lib.start(), throwsA(isA<StateError>()));
    });

    for (final syncError in ['', 'late sync failure']) {
      test('invalidates delayed sync result "$syncError"', () async {
        service.pendingSync = Completer<String>();
        final started = lib.start();
        await service.syncStarted.future;
        final closed = lib.close();
        service.pendingSync!.complete(syncError);

        expect((await started).outcome, CoreLifecycleOutcome.superseded);
        expect((await closed).outcome, CoreLifecycleOutcome.applied);
        expect(service.calls, ['init', 'syncState', 'shutdown']);
        expect(
          await lib.invokeMethod<String>(method: CoreMethod.getProxies),
          isNull,
        );
      });
    }

    test('a late init error cannot override close', () async {
      service.pendingInit = Completer<String>();
      final started = lib.start();
      await Future<void>.delayed(Duration.zero);
      final closed = lib.close();
      service.pendingInit!.complete('late init failure');

      expect((await started).outcome, CoreLifecycleOutcome.superseded);
      expect((await closed).outcome, CoreLifecycleOutcome.coalesced);
      expect(service.calls, ['init']);
    });

    test('close supersedes restart waiting for shutdown', () async {
      await lib.start();
      service.calls.clear();
      service.pendingShutdown = Completer<bool>();
      final restarted = lib.restart();
      await service.shutdownStarted.future;
      final closed = lib.close();
      service.pendingShutdown!.complete(true);

      expect((await restarted).outcome, CoreLifecycleOutcome.superseded);
      await closed;
      expect(service.calls, ['shutdown']);
    });

    test('releases method calls waiting for a connection', () async {
      final pending = lib.invokeMethod<String>(method: CoreMethod.getProxies);
      await lib.close();

      expect(await pending, isNull);
      expect(service.calls, isEmpty);
    });

    test('runs the shutdown once no matter how often it is called', () async {
      await lib.start();
      service.calls.clear();

      final first = lib.close();
      final second = lib.close();

      expect(identical(first, second), isTrue);
      await first;
      await second;

      expect(service.calls, ['shutdown']);
    });
  });

  group('listeners', () {
    test('a listener is started only when both sides agree', () async {
      await lib.start();
      service.onInvokeMethod = (_) =>
          const CoreMethodResponse(id: '1', result: true);

      expect(await lib.startListener(), isTrue);

      service.startResult = false;
      expect(await lib.startListener(), isFalse);
    });

    test('stopListener stops the service before the core listener', () async {
      await lib.start();
      service.onInvokeMethod = (_) =>
          const CoreMethodResponse(id: '1', result: true);
      service.calls.clear();

      expect(await lib.stopListener(), isTrue);
      expect(service.calls, ['stop', 'invokeMethod:stopListener']);
    });
  });

  group('invokeMethod', () {
    test('assigns an increasing call id per request', () async {
      await lib.start();
      service.onInvokeMethod = (call) =>
          CoreMethodResponse(id: call.id, result: 'ok');

      await lib.invokeMethod<String>(method: CoreMethod.getProxies);
      await lib.invokeMethod<String>(method: CoreMethod.getProxies);

      expect(service.invokedCalls.map((call) => call.id), ['1', '2']);
    });

    test('unwraps the response payload', () async {
      await lib.start();
      service.onInvokeMethod = (call) =>
          CoreMethodResponse(id: call.id, result: 'payload');

      expect(
        await lib.invokeMethod<String>(method: CoreMethod.getProxies),
        'payload',
      );
    });

    test('resolves to null when the service answers nothing', () async {
      await lib.start();
      service.onInvokeMethod = (_) => null;

      expect(
        await lib.invokeMethod<String>(method: CoreMethod.getProxies),
        isNull,
      );
    });

    testWidgets('gives up instead of hanging when no connection arrives', (
      tester,
    ) async {
      Object? result = 'unset';
      final pending = lib
          .invokeMethod<String>(method: CoreMethod.getProxies)
          .then((value) => result = value);

      await tester.pump(const Duration(seconds: 11));
      await pending;

      expect(result, isNull);
      expect(service.calls, isEmpty);
    });
  });
}
