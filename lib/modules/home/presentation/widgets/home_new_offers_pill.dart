import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

/// "● 3 new offers >" — chỉ hiện khi có offer mới.
class HomeNewOffersPill extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const HomeNewOffersPill({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: count <= 0
          ? SizedBox(width: double.infinity, height: 40.h)
          : Padding(
              padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
              child: Material(
                color: theme.muted(context),
                shape: const StadiumBorder(),
                child: InkWell(
                  // TODO(offers): mở danh sách offer khi có màn buyer offers.
                  onTap: onTap,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.h,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.r,
                          height: 6.r,
                          decoration: BoxDecoration(
                            color: theme.textPrimary(context),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Gap(6.w),
                        Text(
                          count == 1
                              ? LocaleKeys.homeNewOffersOne.tr()
                              : LocaleKeys.homeNewOffersMany.tr(
                                  args: ['$count'],
                                ),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: theme.textPrimary(context),
                          ),
                        ),
                        Gap(4.w),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18.r,
                          color: theme.textPrimary(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
