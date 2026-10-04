import 'dart:io';

import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'built-in script has AOT identity and loads the unchanged asset',
    () async {
      final script = Script.builtInDickService();
      expect(script.id, -10086);
      expect(script.label, 'Dick Service');
      expect(script.lastUpdateTime, DateTime(2026));
      expect(
        await script.content,
        await File('assets/data/dick_rule.js').readAsString(),
      );
    },
  );
}
