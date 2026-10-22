import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/import/qr_pairing.dart';

void main() {
  testWidgets('first launch uses scenic artwork and prominent source choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TviumApp());

    final backdrop = tester.widget<Image>(
      find.byKey(const ValueKey('onboarding-backdrop')),
    );
    expect(
      (backdrop.image as AssetImage).assetName,
      'assets/destinations/hero-home.png',
    );
    final url = tester.getRect(
      find.byKey(const ValueKey<String>('m3u-url-action')),
    );
    final file = tester.getRect(
      find.byKey(const ValueKey<String>('m3u-file-action')),
    );
    final xtream = tester.getRect(
      find.byKey(const ValueKey<String>('xtream-action')),
    );
    expect(url.width, greaterThanOrEqualTo(240));
    expect(url.height, greaterThanOrEqualTo(130));
    expect(url.right, lessThan(file.left));
    expect(file.right, lessThan(xtream.left));
  });

  testWidgets('QR pairing is visible on a 720p TV without scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TviumApp());
    final rect = tester.getRect(
      find.byKey(const ValueKey('qr-pairing-action')),
    );
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(720));
  });

  testWidgets('TV remote can open QR pairing from the first source card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = _FakeQrPairingSession();
    await tester.pumpWidget(TviumApp(qrPairingStarter: () async => session));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('qr-pairing-code')), findsOneWidget);
  });

  testWidgets('explains source ownership before the first import', (
    tester,
  ) async {
    await tester.pumpWidget(const TviumApp());

    expect(
      find.byKey(const ValueKey<String>('tvium-brand-logo')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Tvium'), findsOneWidget);
    expect(find.text('Welcome to Tvium'), findsOneWidget);
    expect(
      find.text('Add your own IPTV source to get started.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tvium does not provide TV channels, playlists or subscriptions.',
      ),
      findsOneWidget,
    );
    expect(find.text('M3U URL'), findsOneWidget);
    expect(find.text('Import local M3U'), findsOneWidget);
    expect(find.text('Xtream Codes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('m3u-url-action')));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('keeps every source action visible on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TviumApp());

    for (final key in const <String>[
      'm3u-url-action',
      'm3u-file-action',
      'xtream-action',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
    }
  });

  testWidgets('opens a protected Xtream connection form', (tester) async {
    await tester.pumpWidget(const TviumApp());

    await tester.tap(find.byKey(const ValueKey<String>('xtream-action')));
    await tester.pump();

    expect(find.text('Profile name'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Test connection'), findsOneWidget);
    expect(find.text('Add playlist'), findsOneWidget);

    final serverField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('xtream-server-url')),
    );
    final passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('xtream-password')),
    );
    expect(serverField.obscureText, isTrue);
    expect(serverField.enableSuggestions, isFalse);
    expect(passwordField.obscureText, isTrue);
    expect(passwordField.enableSuggestions, isFalse);
  });

  testWidgets('QR handoff waits for TV confirmation before adding a source', (
    tester,
  ) async {
    final session = _FakeQrPairingSession();
    await tester.pumpWidget(TviumApp(qrPairingStarter: () async => session));
    await tester.ensureVisible(find.byKey(const ValueKey('qr-pairing-action')));
    await tester.tap(find.byKey(const ValueKey('qr-pairing-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qr-pairing-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('qr-pairing-confirm')), findsNothing);

    session.complete(
      QrM3uSubmission(Uri.parse('https://playlist.example.test/list.m3u')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qr-pairing-confirm')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('qr-pairing-source-type')),
      findsOneWidget,
    );
    expect(find.text('M3U URL'), findsWidgets);
    expect(find.textContaining('playlist.example.test'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session.closed, isTrue);
  });

  testWidgets(
    'QR confirmation identifies an Xtream source without credentials',
    (tester) async {
      final session = _FakeQrPairingSession();
      await tester.pumpWidget(TviumApp(qrPairingStarter: () async => session));
      await tester.ensureVisible(
        find.byKey(const ValueKey('qr-pairing-action')),
      );
      await tester.tap(find.byKey(const ValueKey('qr-pairing-action')));
      await tester.pumpAndSettle();
      session.complete(
        QrXtreamSubmission(
          Uri.parse('https://provider.example.test'),
          'synthetic-user',
          'synthetic-password',
        ),
      );
      await tester.pumpAndSettle();
      final sourceType = find.byKey(const ValueKey('qr-pairing-source-type'));
      expect(sourceType, findsOneWidget);
      expect(tester.widget<Text>(sourceType).data, 'Xtream Codes');
      expect(find.textContaining('synthetic-password'), findsNothing);
      expect(find.textContaining('provider.example.test'), findsNothing);
    },
  );
}

final class _FakeQrPairingSession implements QrPairingSession {
  final Completer<QrPairingSubmission?> _received = Completer();
  bool closed = false;

  @override
  String get pairingUrl => 'http://192.168.1.2:12345/pair/temporary-code';

  @override
  Future<QrPairingSubmission?> get submission => _received.future;

  void complete(QrPairingSubmission submission) =>
      _received.complete(submission);

  @override
  Future<void> close() async {
    closed = true;
    if (!_received.isCompleted) _received.complete(null);
  }
}
