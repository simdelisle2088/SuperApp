import 'package:flutter/material.dart';

class VersionDisplay extends StatelessWidget {
  const VersionDisplay({
    super.key,
    this.version = '1.6.4',
    this.color = Colors.white,
    this.fontSize = 16.0,
  });

  final String version;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Text(
            'version $version',
            style: TextStyle(
              color: color,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }
}
