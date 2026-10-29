import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Khoảng cách chuẩn. Chỉ đọc sau khi `ScreenUtilInit` đã chạy.
class AppSpacing {
  AppSpacing._();

  static double get xs => 4.w;
  static double get sm => 8.w;
  static double get md => 12.w;
  static double get lg => 16.w;
  static double get xl => 24.w;
  static double get xxl => 32.w;

  /// Padding ngang mặc định của màn hình.
  static double get screenHorizontal => 16.w;
}
