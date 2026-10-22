import 'qr_pairing.dart';

Future<QrPairingSession> startQrPairing() => Future<QrPairingSession>.error(
  UnsupportedError('Local pairing requires a TV app'),
);
