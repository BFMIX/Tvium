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
  final TextEditingController _searchController = TextEditingController();
  MediaKind _kind = MediaKind.live;
  String _query = '';
  var _busy = false;
  List<CatalogCategory>? _categories;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
      body: Center(
        child: ConstrainedBox(
          key: const ValueKey('category-manager-content'),
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: <Widget>[
                    for (final (kind, label) in <(MediaKind, String)>[
                      (MediaKind.live, 'Live TV'),
                      (MediaKind.movie, 'Movies'),
                      (MediaKind.episode, 'TV Shows'),
                    ])
                      Expanded(
                        child: InkWell(
                          key: ValueKey('category-kind-${kind.name}'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            if (_kind == kind) return;
                            setState(() {
                              _kind = kind;
                              _categories = null;
                              _query = '';
                            });
                            _searchController.clear();
                            _load();
                          },
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _kind == kind
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant,
                                  width: _kind == kind ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              label,
                              style: textTheme.labelLarge?.copyWith(
                                color: _kind == kind
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: TextField(
                  key: ValueKey('category-search-${_kind.name}'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search category, country, or playlist',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: <Widget>[
                    Text(
                      '${matching.length} matching',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('category-hide-all'),
                      onPressed: _busy || categories == null || hideCount == 0
                          ? null
                          : () => _setVisible(categories, false),
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: Text('Hide all ($hideCount)'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('category-show-matching'),
                      onPressed: _busy || categories == null || showCount == 0
                          ? null
                          : () => _setVisible(matching, true),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text('Show matching ($showCount)'),
                    ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: categories == null
                    ? const Center(child: CircularProgressIndicator())
                    : matching.isEmpty
                    ? Center(
                        child: Text(
                          _query.isEmpty
                              ? 'No categories in this section'
                              : 'No matching categories',
                          style: textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: matching.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final category = matching[index];
                          final name = category.groupName ?? 'Uncategorized';
                          return Semantics(
                            button: true,
                            label:
                                '${category.visible ? 'Hide' : 'Show'} $name',
                            child: InkWell(
                              key: ValueKey(
                                'category-${category.sourceId}-${category.kind.name}-${category.groupName}',
                              ),
                              onTap: _busy
                                  ? null
                                  : () => _setVisible([
                                      category,
                                    ], !category.visible),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: category.visible
                                                      ? colorScheme.onSurface
                                                      : colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${sourceNames[category.sourceId] ?? 'Playlist'} · ${category.count} items',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      category.visible
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: category.visible
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
