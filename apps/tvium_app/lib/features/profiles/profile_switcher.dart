import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_database/tvium_database.dart';

import '../library/library_bootstrap_controller.dart';

/// A compact profile menu for households sharing the same device.
final class ProfileSwitcher extends ConsumerWidget {
  const ProfileSwitcher({
    this.onProfileChanged,
    this.onSourcesRemoved,
    super.key,
  });

  final VoidCallback? onProfileChanged;
  final Future<void> Function(List<IptvSource> sources)? onSourcesRemoved;

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
                  trailing: Wrap(
                    spacing: 4,
                    children: <Widget>[
                      IconButton(
                        key: ValueKey('rename-profile-${profile.id}'),
                        tooltip: 'Rename profile',
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(_ProfileAction.rename(profile.id)),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        key: ValueKey('delete-profile-${profile.id}'),
                        tooltip: snapshot.profiles.length <= 1
                            ? 'At least one profile is required'
                            : 'Delete profile',
                        onPressed: snapshot.profiles.length <= 1
                            ? null
                            : () =>
                                  Navigator.of(context)
                                      .pop(_ProfileAction.delete(profile.id)),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
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
    if (action.kind == _ProfileActionKind.create) {
      await _showCreateProfile(context, onProfileChanged);
      return;
    }
    final repository = await ref.read(libraryRepositoryProvider.future);
    if (action.kind == _ProfileActionKind.rename) {
      await _showRenameProfile(
        context,
        repository,
        snapshot.profiles.firstWhere(
          (profile) => profile.id == action.profileId,
        ),
      );
    } else if (action.kind == _ProfileActionKind.delete) {
      final confirmed = await _confirmDeleteProfile(
        context,
        snapshot.profiles.firstWhere(
          (profile) => profile.id == action.profileId,
        ),
      );
      if (!confirmed) return;
      final removed = await repository.deleteProfile(action.profileId!);
      await onSourcesRemoved?.call(removed);
    } else {
      await repository.setActiveProfile(action.profileId!);
    }
    onProfileChanged?.call();
    ref.invalidate(libraryBootstrapProvider);
  }

  Future<void> _showRenameProfile(
    BuildContext context,
    ProfileSourceRepository repository,
    UserProfile profile,
  ) => showDialog<void>(
    context: context,
    builder: (context) =>
        _RenameProfileDialog(repository: repository, profile: profile),
  );

  Future<bool> _confirmDeleteProfile(
    BuildContext context,
    UserProfile profile,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete profile?'),
          content: Text(
            'Delete ${profile.displayName} from this device? Shared playlists remain available to other profiles.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

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

final class _RenameProfileDialog extends StatefulWidget {
  const _RenameProfileDialog({required this.repository, required this.profile});

  final ProfileSourceRepository repository;
  final UserProfile profile;

  @override
  State<_RenameProfileDialog> createState() => _RenameProfileDialogState();
}

final class _RenameProfileDialogState extends State<_RenameProfileDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.profile.displayName,
  );
  String? _validationMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename profile'),
    content: TextField(
      key: const ValueKey('rename-profile-field'),
      controller: _controller,
      autofocus: true,
      maxLength: 80,
      decoration: InputDecoration(
        labelText: 'Profile name',
        errorText: _validationMessage,
      ),
      onSubmitted: (_) => _save(),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );

  Future<void> _save() async {
    try {
      await widget.repository.renameProfile(
        widget.profile.id,
        _controller.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError {
      setState(() => _validationMessage = 'Choose a unique profile name.');
    }
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
  const _ProfileAction.select(this.profileId)
    : kind = _ProfileActionKind.select;

  const _ProfileAction.create()
    : profileId = null,
      kind = _ProfileActionKind.create;

  const _ProfileAction.rename(this.profileId)
    : kind = _ProfileActionKind.rename;

  const _ProfileAction.delete(this.profileId)
    : kind = _ProfileActionKind.delete;

  final String? profileId;
  final _ProfileActionKind kind;
}

enum _ProfileActionKind { select, create, rename, delete }
