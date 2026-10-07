import 'dart:io';

import 'package:fl_clash/common/constant.dart' as constants;
import 'package:test/test.dart';

/// The Dart MethodChannel base (`packageName`) and the Kotlin
/// `Components.PACKAGE_NAME` must stay identical. They are two independent
/// hard-coded strings, so a branding change that only edits one side silently
/// breaks every `app`/`service`/`tile` call with a `MissingPluginException`
/// that no Dart unit test can see.
void main() {
  test('Dart channel base matches Kotlin Components.PACKAGE_NAME', () {
    final kotlin = File(
      'android/common/src/main/java/com/follow/clash/common/Components.kt',
    );
    expect(kotlin.existsSync(), isTrue, reason: '${kotlin.path} moved');
    final match = RegExp(
      r'PACKAGE_NAME\s*=\s*"([^"]+)"',
    ).firstMatch(kotlin.readAsStringSync());
    expect(match, isNotNull, reason: 'PACKAGE_NAME declaration not found');
    expect(
      constants.packageName,
      match!.group(1),
      reason:
          'Dart `packageName` is the Android MethodChannel base; it must equal '
          'the Kotlin Components.PACKAGE_NAME or platform calls fail.',
    );
  });
}
