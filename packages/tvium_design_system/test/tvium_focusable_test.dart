import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_design_system/tvium_design_system.dart';

void main() {
  testWidgets('activates from Enter and exposes visible focused state', (
    tester,
  ) async {
    var activations = 0;
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: TviumTheme.dark(),
        home: Scaffold(
          body: TviumFocusable(
            focusNode: node,
            onActivate: () => activations++,
            child: const Text('Source'),
          ),
        ),
      ),
    );

    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activations, 1);
    final animated = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(TviumFocusable),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = animated.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
  });
}
