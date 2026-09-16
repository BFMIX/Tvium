import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_design_system/tvium_design_system.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

import '../../l10n/generated/app_localizations.dart';
import 'xtream_connection_service.dart';

final class XtreamConnectionForm extends ConsumerStatefulWidget {
  const XtreamConnectionForm({super.key});

  @override
  ConsumerState<XtreamConnectionForm> createState() =>
      _XtreamConnectionFormState();
}

final class _XtreamConnectionFormState
    extends ConsumerState<XtreamConnectionForm> {
  final _profileController = TextEditingController();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscureServer = true;
  var _obscurePassword = true;
  var _processing = false;
  String? _status;
  var _statusIsError = false;

  @override
  void dispose() {
    _profileController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('xtream-profile-name'),
            controller: _profileController,
            enabled: !_processing,
            decoration: InputDecoration(labelText: strings.profileName),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: TviumSpacing.sm),
          TextField(
            key: const ValueKey<String>('xtream-server-url'),
            controller: _serverController,
            enabled: !_processing,
            keyboardType: TextInputType.url,
            obscureText: _obscureServer,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: strings.serverUrl,
              suffixIcon: IconButton(
                tooltip: _obscureServer
                    ? strings.showServerUrl
                    : strings.hideServerUrl,
                onPressed: () =>
                    setState(() => _obscureServer = !_obscureServer),
                icon: Icon(
                  _obscureServer
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: TviumSpacing.sm),
          TextField(
            key: const ValueKey<String>('xtream-username'),
            controller: _usernameController,
            enabled: !_processing,
            decoration: InputDecoration(labelText: strings.username),
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.username],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: TviumSpacing.sm),
          TextField(
            key: const ValueKey<String>('xtream-password'),
            controller: _passwordController,
            enabled: !_processing,
            decoration: InputDecoration(
              labelText: strings.password,
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? strings.showPassword
                    : strings.hidePassword,
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            obscureText: _obscurePassword,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.password],
            onSubmitted: (_) => _run(addPlaylist: false),
          ),
          if (kIsWeb) ...<Widget>[
            const SizedBox(height: TviumSpacing.sm),
            Text(
              strings.webSessionStorageNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_status != null) ...<Widget>[
            const SizedBox(height: TviumSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                _status!,
                key: const ValueKey<String>('xtream-status'),
                style: TextStyle(
                  color: _statusIsError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: TviumSpacing.md),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: TviumSpacing.sm,
            runSpacing: TviumSpacing.sm,
            children: <Widget>[
              OutlinedButton(
                key: const ValueKey<String>('xtream-test-connection'),
                onPressed: _processing ? null : () => _run(addPlaylist: false),
                child: Text(strings.testConnection),
              ),
              FilledButton(
                key: const ValueKey<String>('xtream-add-playlist'),
                onPressed: _processing ? null : () => _run(addPlaylist: true),
                child: Text(strings.addPlaylist),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _run({required bool addPlaylist}) async {
    final strings = AppLocalizations.of(context);
    final input = _readInput();
    if (input == null) {
      setState(() {
        _status = strings.invalidXtreamFields;
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _processing = true;
      _status = null;
    });
    try {
      final service = ref.read(xtreamConnectionServiceProvider);
      if (addPlaylist) {
        final result = await service.addPlaylist(input);
        if (!mounted) return;
        _serverController.clear();
        _usernameController.clear();
        _passwordController.clear();
        TextInput.finishAutofillContext();
        setState(() {
          _status = strings.xtreamPlaylistAdded(result.itemCount);
          _statusIsError = false;
        });
      } else {
        await service.testConnection(input);
        if (!mounted) return;
        setState(() {
          _status = strings.connectionSuccessful;
          _statusIsError = false;
        });
      }
    } on XtreamException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _failureMessage(strings, error.failure);
        _statusIsError = true;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _status = strings.connectionFailed;
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  XtreamConnectionInput? _readInput() {
    final profileName = _profileController.text.trim();
    final serverUri = Uri.tryParse(_serverController.text.trim());
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (profileName.isEmpty ||
        serverUri == null ||
        !serverUri.hasAuthority ||
        (serverUri.scheme != 'http' && serverUri.scheme != 'https') ||
        username.isEmpty ||
        password.isEmpty) {
      return null;
    }
    return XtreamConnectionInput(
      profileName: profileName,
      serverUri: serverUri,
      credentials: XtreamCredentials(username: username, password: password),
    );
  }

  String _failureMessage(AppLocalizations strings, XtreamFailure failure) {
    return switch (failure) {
      XtreamFailure.incorrectCredentials => strings.incorrectCredentials,
      XtreamFailure.networkTimeout => strings.networkTimeout,
      XtreamFailure.serverUnreachable ||
      XtreamFailure.unavailable => strings.serverUnreachable,
      XtreamFailure.invalidResponse => strings.invalidProviderResponse,
    };
  }
}
