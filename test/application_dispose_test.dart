import 'dart:async';

import 'package:fl_clash/application.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

class _ExitAction extends SystemAction {
  final List<String> calls;
  final Object? error;

  _ExitAction(this.calls, this.error);

  @override
  Future<void> handleExit([bool needSave = true]) async {
    calls.add('exit');
    final failure = error;
    if (failure != null) {
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
  }
}

class _DisposeApplication extends Application {
  const _DisposeApplication();

  @override
  ConsumerState<Application> createState() => _DisposeApplicationState();
}

class _DisposeApplicationState extends ApplicationState {
  @override
  // ignore: must_call_super
  void initState() {}

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  for (final closeFails in [false, true]) {
    testWidgets(
      'dispose is synchronous and exits after core close ${closeFails ? 'fails' : 'completes'}',
      (tester) async {
        final calls = <String>[];
        final logs = <String>[];
        final close = Completer<CoreLifecycleResult>();
        final core = _MockCore();
        when(() => core.close()).thenAnswer((_) {
          calls.add('close');
          return close.future;
        });
        final container = ProviderContainer(
          overrides: [
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            systemActionProvider.overrideWith(() => _ExitAction(calls, null)),
          ],
        );
        addTearDown(container.dispose);
        final originalDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          if (message != null) logs.add(message);
        };
        addTearDown(() => debugPrint = originalDebugPrint);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _DisposeApplication(),
          ),
        );
        await tester.pumpWidget(const SizedBox());

        expect(tester.takeException(), isNull);
        expect(calls, ['close']);
        if (closeFails) {
          close.completeError(StateError('close failed'));
        } else {
          close.complete(
            const CoreLifecycleResult(
              outcome: CoreLifecycleOutcome.applied,
              revision: 1,
            ),
          );
        }
        await tester.pump();

        expect(calls, ['close', 'exit']);
        expect(tester.takeException(), isNull);
        if (closeFails) {
          expect(logs, contains(contains('Application core close failed:')));
        }
        debugPrint = originalDebugPrint;
      },
    );
  }

  testWidgets('synchronous close and async exit errors are logged', (
    tester,
  ) async {
    final calls = <String>[];
    final logs = <String>[];
    final core = _MockCore();
    when(() => core.close()).thenAnswer((_) {
      calls.add('close');
      throw StateError('sync close failed');
    });
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        systemActionProvider.overrideWith(
          () => _ExitAction(calls, StateError('exit failed')),
        ),
      ],
    );
    addTearDown(container.dispose);
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _DisposeApplication(),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(calls, ['close', 'exit']);
    expect(tester.takeException(), isNull);
    expect(logs, contains(contains('Application core close failed:')));
    expect(logs, contains(contains('Application exit failed:')));
    debugPrint = originalDebugPrint;
  });
}
