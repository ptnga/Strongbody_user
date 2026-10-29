import 'package:flutter/material.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';

/// Logo StrongBody.ai: ô "S" (`logo_mark.png`, cùng logo app icon) + chữ "StrongBody" và ".ai" màu đỏ.
/// [height] = cạnh ô vuông; chữ co theo tỉ lệ.
class StrongBodyLogo extends StatelessWidget {
  const StrongBodyLogo({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    final wordStyle = TextStyle(
      fontSize: height * 0.72,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      height: 1,
      color: Colour.textPrimary,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo_mark.png',
          width: height,
          height: height,
          filterQuality: FilterQuality.medium,
        ),
        SizedBox(width: height * 0.36),
        Text.rich(
          TextSpan(
            text: 'StrongBody',
            children: const [
              TextSpan(
                text: '.ai',
                style: TextStyle(color: Colour.primary),
              ),
            ],
          ),
          style: wordStyle,
        ),
      ],
    );
  }
}
