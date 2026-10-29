import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';

/// Logo StrongBody.ai: biểu tượng sư tử (`assets/svg/favicon.svg`, cùng logo app icon) +
/// chữ "StrongBody" và ".ai" màu đỏ.
///
/// Tỉ lệ đo từ logo splash Multime (`logo_muti.png`): chữ hoa cao ~51% biểu tượng,
/// nét dày ~20% chữ hoa (ExtraBold), khoảng cách chữ thường, chữ cách biểu tượng ~17%.
/// [height] = cạnh biểu tượng.
class StrongBodyLogo extends StatelessWidget {
  const StrongBodyLogo({super.key, this.height = 28});

  final double height;

  static const markAsset = 'assets/svg/favicon.svg';

  @override
  Widget build(BuildContext context) {
    final wordStyle = TextStyle(
      fontSize: height * 0.68,
      fontWeight: FontWeight.w800,
      height: 1,
      color: Colour.textPrimary,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(markAsset, width: height, height: height),
        SizedBox(width: height * 0.12),
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
