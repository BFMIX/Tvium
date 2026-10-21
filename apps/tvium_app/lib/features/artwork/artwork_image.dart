import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final artworkCache = CacheManager(
  Config(
    'tviumArtwork',
    stalePeriod: const Duration(days: 90),
    maxNrOfCacheObjects: 2000,
  ),
);

String artworkCacheKey(String sourceId, String entryId, String role) => sha256
    .convert(utf8.encode('$sourceId\u0000$entryId\u0000$role'))
    .toString();

/// Uses an opaque cache key so artwork can be found after catalog restoration.
/// Artwork URLs are not copied into the catalog's indexed rows.
final class ArtworkImage extends StatefulWidget {
  const ArtworkImage({
    required this.sourceId,
    required this.entryId,
    required this.role,
    required this.uri,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallback,
    super.key,
  });

  final String sourceId;
  final String entryId;
  final String role;
  final Uri? uri;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? fallback;

  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

final class _ArtworkImageState extends State<ArtworkImage> {
  Future<Uint8List?>? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _loadCachedBytes();
  }

  @override
  void didUpdateWidget(covariant ArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId ||
        oldWidget.entryId != widget.entryId ||
        oldWidget.role != widget.role ||
        oldWidget.uri != widget.uri) {
      _loadCachedBytes();
    }
  }

  void _loadCachedBytes() {
    final uri = widget.uri;
    if (uri != null && uri.hasScheme && !uri.host.endsWith('.test')) {
      _cachedBytes = null;
      return;
    }
    if (kIsWeb) {
      _cachedBytes = Future<Uint8List?>.value(null);
      return;
    }
    _cachedBytes = _readCachedBytes();
  }

  Future<Uint8List?> _readCachedBytes() async {
    final key = artworkCacheKey(widget.sourceId, widget.entryId, widget.role);
    final cached = await artworkCache.getFileFromCache(key);
    return cached?.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    final uri = widget.uri;
    if (uri != null && uri.hasScheme && !uri.host.endsWith('.test')) {
      return CachedNetworkImage(
        imageUrl: uri.toString(),
        cacheKey: artworkCacheKey(widget.sourceId, widget.entryId, widget.role),
        cacheManager: artworkCache,
        fit: widget.fit,
        alignment: widget.alignment,
        errorWidget: (context, url, error) =>
            widget.fallback ?? const SizedBox.shrink(),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _cachedBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return bytes == null
            ? widget.fallback ?? const SizedBox.shrink()
            : Image.memory(bytes, fit: widget.fit, alignment: widget.alignment);
      },
    );
  }
}
