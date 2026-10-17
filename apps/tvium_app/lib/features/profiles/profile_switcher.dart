import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/library_bootstrap_controller.dart';

/// A compact profile menu for households sharing the same device.
final class ProfileSwitcher extends ConsumerWidget {
  const ProfileSwitcher({this.onProfileChanged, super.key});

  final VoidCallback? onProfileChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryBootstrapProvider);
    return library.when(
      data: (snapshot) => TextButton.icon(
        key: const ValueKey('profile-action'),
        onPressed: () => _showProfiles(context, ref, snapshot),
        icon: const Icon(Icons.account_circle_outlined),
        label: Text(snapshot.activeProfile.displayName),
      ),
      error: (error, stackTrace) => IconButton(
        key: const ValueKey('profile-switcher-error'),
        tooltip: 'Profiles are unavailable',
        onPressed: () => ref.invalidate(libraryBootstrapProvider),
        icon: const Icon(Icons.account_circle_outlined),
      ),
      loading: () => const IconButton(
        key: ValueKey('profile-switcher-loading'),
        tooltip: 'Loading profiles',
        onPressed: null,
        icon: Icon(Icons.account_circle_outlined),
      ),
    );
  }

  Future<void> _showProfiles(
    BuildContext context,
    WidgetRef ref,
    LibrarySnapshot snapshot,
  ) async {
    final action = await showModalBottomSheet<_ProfileAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                title: Text('Profiles'),
                subtitle: Text('Each profile keeps its own sources.'),
              ),
              for (final profile in snapshot.profiles)
                ListTile(
                  leading: Icon(
                    profile.id == snapshot.activeProfile.id
                        ? Icons.check_circle
                        : Icons.account_circle_outlined,
                  ),
                  title: Text(profile.displayName),
                  selected: profile.id == snapshot.activeProfile.id,
                  onTap: () =>
                      Navigator.of(context)
                          .pop(_ProfileAction.select(profile.id)),
                ),
              ListTile(
                key: const ValueKey('add-profile'),
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Add profile'),
                onTap: () =>
                    Navigator.of(context).pop(const _ProfileAction.create()),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action.createNew) {
      await _showCreateProfile(context, onProfileChanged);
      return;
    }
    final repository = await ref.read(libraryRepositoryProvider.future);
    await repository.setActiveProfile(action.profileId!);
    onProfileChanged?.call();
    ref.invalidate(libraryBootstrapProvider);
  }

  Future<void> _showCreateProfile(
    BuildContext context,
    VoidCallback? onProfileChanged,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _CreateProfileDialog(onProfileChanged: onProfileChanged),
    );
  }
}

final class _CreateProfileDialog extends ConsumerStatefulWidget {
  const _CreateProfileDialog({this.onProfileChanged});

  final VoidCallback? onProfileChanged;

  @override
  ConsumerState<_CreateProfileDialog> createState() =>
      _CreateProfileDialogState();
}

final class _CreateProfileDialogState
    extends ConsumerState<_CreateProfileDialog> {
  final _controller = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create profile'),
      content: TextField(
        key: const ValueKey('profile-name-field'),
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(
          labelText: 'Profile name',
          errorText: _validationMessage,
        ),
        onSubmitted: (_) => _createProfile(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _createProfile, child: const Text('Create')),
      ],
    );
  }

  Future<void> _createProfile() async {
    try {
      final repository = await ref.read(libraryRepositoryProvider.future);
      final profile = await repository.createProfile(_controller.text);
      await repository.setActiveProfile(profile.id);
      widget.onProfileChanged?.call();
      ref.invalidate(libraryBootstrapProvider);
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError {
      setState(() => _validationMessage = 'Choose a unique profile name.');
    }
  }
}

final class _ProfileAction {
  const _ProfileAction.select(this.profileId) : createNew = false;

  const _ProfileAction.create() : profileId = null, createNew = true;

  final String? profileId;
  final bool createNew;
}
