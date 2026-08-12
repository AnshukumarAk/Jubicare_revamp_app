import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Vector rendering of the JubiCare wordmark so the prototype carries the
/// brand identity without depending on an external image asset.
class JubiCareLogo extends StatelessWidget {
  final double fontSize;
  final bool onDark;
  const JubiCareLogo({super.key, this.fontSize = 34, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final jubiColor = onDark ? Colors.white : JC.navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _dot(JC.teal, 7),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('JUBI',
                style: TextStyle(
                    fontSize: fontSize,
                    height: 0.95,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: jubiColor)),
            Text('CARE',
                style: TextStyle(
                    fontSize: fontSize,
                    height: 0.95,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: JC.sky)),
          ],
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _dot(JC.yellow, 6),
            const SizedBox(height: 10),
            _dot(JC.blue, 6),
          ],
        ),
      ],
    );
  }

  Widget _dot(Color c, double r) =>
      Container(width: r * 2, height: r * 2, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
