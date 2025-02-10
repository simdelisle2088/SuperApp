import 'package:flutter/material.dart';

/// A widget that displays the background image.
class BackgroundImage extends StatelessWidget {
  /// Creates a new instance of [BackgroundImage].
  final String url;

  const BackgroundImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(url),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}