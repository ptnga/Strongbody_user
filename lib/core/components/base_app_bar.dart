import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/theme.dart';

class BaseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Ghi đè [title] khi tiêu đề cần đổi theo state (vd bọc BlocSelector).
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;

  const BaseAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      actions: actions,
      title: titleWidget ?? BaseAppBarTitle(text: title),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class BaseAppBarTitle extends StatelessWidget {
  final String text;

  const BaseAppBarTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).textPrimary(context),
      ),
    );
  }
}
