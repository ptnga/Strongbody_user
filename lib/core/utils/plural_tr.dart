import 'package:easy_localization/easy_localization.dart';

/// Chuỗi theo số lượng từ 2 key phẳng `xOne` / `xOther` (`{}` = số).
String pluralTr(int count, {required String one, required String other}) =>
    (count == 1 ? one : other).tr(args: ['$count']);
