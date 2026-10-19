import 'package:flutter/material.dart';

final class TviumBrandLogo extends StatelessWidget {
  const TviumBrandLogo({
    required this.semanticLabel,
    this.height = 32,
    super.key,
  });

  static const String assetPath = 'assets/branding/logo-primary-color.png';

  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) => Text(
        semanticLabel,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
