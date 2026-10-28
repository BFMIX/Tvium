import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'features/artwork/artwork_cache_budget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TviumApp());
  unawaited(pruneArtworkCache());
}
