import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_design_system/tvium_design_system.dart';

void main() {
  testWidgets('focuses the first source action on a wide remote layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TviumApp());
    await tester.pump();

    final urlAction = find.descendant(
      of: find.byKey(const ValueKey<String>('m3u-url-action')),
      matching: find.byType(TviumFocusable),
    );
    expect(
      tester.widget<TviumFocusable>(urlAction).focusNode?.hasFocus,
      isTrue,
    );
  });

  testWidgets('moves focus horizontally between source actions', (
    tester,
  ) async {
    await tester.pumpWidget(const TviumApp());

    final urlCard = find.byKey(const ValueKey<String>('m3u-url-action'));
    final fileCard = find.byKey(const ValueKey<String>('m3u-file-action'));
    final urlAction = find.descendant(
      of: urlCard,
      matching: find.byType(TviumFocusable),
    );
    final fileAction = find.descendant(
      of: fileCard,
      matching: find.byType(TviumFocusable),
    );
    expect(urlCard, findsOneWidget);
    expect(fileCard, findsOneWidget);
    expect(urlAction, findsOneWidget);
    expect(fileAction, findsOneWidget);

    await tester.tap(urlCard);
    await tester.pump();
    expect(
      tester.widget<TviumFocusable>(urlAction).focusNode?.hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(
      tester.widget<TviumFocusable>(fileAction).focusNode?.hasFocus,
      isTrue,
    );
  });
}
