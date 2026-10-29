import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icon SVG dùng chung. `tint=true` (mặc định) tô màu đơn sắc theo [color]
/// hoặc màu IconTheme hiện tại (giống Material Icon). Brand/đa màu: `tint:false`.
class AppIcon extends StatelessWidget {
  final String asset;
  final double? size;
  final Color? color;
  final bool tint;
  const AppIcon(this.asset, {super.key, this.size, this.color, this.tint = true});

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: (tint && resolved != null)
          ? ColorFilter.mode(resolved, BlendMode.srcIn)
          : null,
    );
  }
}
