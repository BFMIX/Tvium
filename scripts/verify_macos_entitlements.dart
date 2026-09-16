import 'dart:io';

const _requiredEntitlements = <String>[
  'com.apple.security.app-sandbox',
  'com.apple.security.network.client',
  'com.apple.security.files.user-selected.read-only',
];

void main(List<String> arguments) {
  if (!Platform.isMacOS) {
    stderr.writeln('macOS entitlement verification requires macOS.');
    exitCode = 2;
    return;
  }
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run scripts/verify_macos_entitlements.dart APP',
    );
    exitCode = 2;
    return;
  }

  final result = Process.runSync('/usr/bin/codesign', <String>[
    '-d',
    '--entitlements',
    ':-',
    arguments.single,
  ]);
  if (result.exitCode != 0) {
    stderr.writeln('Unable to inspect the signed application entitlements.');
    exitCode = 1;
    return;
  }

  final output = '${result.stdout}\n${result.stderr}';
  final missing = _requiredEntitlements
      .where(
        (entitlement) => !RegExp(
          '<key>${RegExp.escape(entitlement)}</key>\\s*<true\\s*/>',
          dotAll: true,
        ).hasMatch(output),
      )
      .toList(growable: false);
  if (missing.isNotEmpty) {
    stderr.writeln('Missing required macOS entitlements:');
    for (final entitlement in missing) {
      stderr.writeln('- $entitlement');
    }
    exitCode = 1;
    return;
  }

  if (!RegExp(
    '<key>keychain-access-groups</key>\\s*<array(?:\\s*/>|>.*?</array>)',
    dotAll: true,
  ).hasMatch(output)) {
    stderr.writeln('Missing required macOS Keychain access entitlement.');
    exitCode = 1;
    return;
  }

  stdout.writeln('Required macOS and Keychain entitlements are present.');
}
