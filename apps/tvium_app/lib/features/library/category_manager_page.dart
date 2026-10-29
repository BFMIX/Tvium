import 'package:flutter/material.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

import 'live_country.dart';

/// Manages local visibility without editing or deleting provider categories.
final class CategoryManagerPage extends StatefulWidget {
  const CategoryManagerPage({
    super.key,
    required this.profileId,
    required this.repository,
    required this.sources,
    required this.onChanged,
  });

  final String profileId;
  final CategoryVisibilityRepository repository;
  final List<IptvSource> sources;
  final VoidCallback onChanged;

  @override
  State<CategoryManagerPage> createState() => _CategoryManagerPageState();
}

final class _CategoryManagerPageState extends State<CategoryManagerPage> {
  MediaKind _kind = MediaKind.live;
  String _query = '';
  var _busy = false;
  List<CatalogCategory>? _categories;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final kind = _kind;
    final categories = await widget.repository.categoriesForProfile(
      widget.profileId,
      kind,
    );
    if (mounted && _kind == kind) {
      setState(() => _categories = categories);
    }
  }

  bool _matches(CatalogCategory category) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final country = _kind == MediaKind.live
        ? countryForGroup(category.groupName)
        : null;
    return (category.groupName ?? 'Uncategorized').toLowerCase().contains(
          query,
        ) ||
        (country?.name.toLowerCase().contains(query) ?? false) ||
        (country?.code.toLowerCase().contains(query) ?? false) ||
        (widget.sources
                .where((source) => source.id == category.sourceId)
                .firstOrNull
                ?.displayName
                .toLowerCase()
                .contains(query) ??
            false);
  }

  Future<void> _setVisible(
    Iterable<CatalogCategory> target,
    bool visible,
  ) async {
    if (_busy) return;
    final changed = target
        .where((category) => category.visible != visible)
        .toList();
    if (changed.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.repository.setCategoriesVisible(
        profileId: widget.profileId,
        categories: changed,
        visible: visible,
      );
      await _load();
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${changed.length} ${changed.length == 1 ? 'category' : 'categories'} updated',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              final keys = changed
                  .map(
                    (category) =>
                        (category.sourceId, category.kind, category.groupName),
                  )
                  .toSet();
              _setVisible(
                _categories!.where(
                  (category) => keys.contains((
                    category.sourceId,
                    category.kind,
                    category.groupName,
                  )),
                ),
                !visible,
              );
            },
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update categories.')),
        );
      }
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    final matching =
        categories?.where(_matches).toList(growable: false) ??
        const <CatalogCategory>[];
    final hideCount =
        categories?.where((category) => category.visible).length ?? 0;
    final showCount = matching.where((category) => !category.visible).length;
    final sourceNames = {
      for (final source in widget.sources) source.id: source.displayName,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Manage categories')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<MediaKind>(
              segments: const <ButtonSegment<MediaKind>>[
                ButtonSegment(value: MediaKind.live, label: Text('Live TV')),
                ButtonSegment(value: MediaKind.movie, label: Text('Movies')),
                ButtonSegment(
                  value: MediaKind.episode,
                  label: Text('TV Shows'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) {
                setState(() {
                  _kind = selection.first;
                  _categories = null;
                  _query = '';
                });
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: ValueKey('category-search-${_kind.name}'),
              decoration: const InputDecoration(
                hintText: 'Search category, country, or playlist',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text('${matching.length} matching'),
                OutlinedButton(
                  key: const ValueKey('category-hide-all'),
                  onPressed: _busy || categories == null || hideCount == 0
                      ? null
                      : () => _setVisible(categories, false),
                  child: Text('Hide all ($hideCount)'),
                ),
                OutlinedButton(
                  key: const ValueKey('category-show-matching'),
                  onPressed: _busy || categories == null || showCount == 0
                      ? null
                      : () => _setVisible(matching, true),
                  child: Text('Show matching ($showCount)'),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: categories == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: matching.length,
                    itemBuilder: (context, index) {
                      final category = matching[index];
                      return SwitchListTile(
                        key: ValueKey(
                          'category-${category.sourceId}-${category.kind.name}-${category.groupName}',
                        ),
                        title: Text(category.groupName ?? 'Uncategorized'),
                        subtitle: Text(
                          '${sourceNames[category.sourceId] ?? 'Playlist'} · ${category.count} items',
                        ),
                        value: category.visible,
                        onChanged: _busy
                            ? null
                            : (visible) => _setVisible([category], visible),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
