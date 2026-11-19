import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/components/base_app_bar.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';

import '../../domain/entities/board_entities.dart';
import '../bloc/board/board_cubit.dart';
import '../widgets/board/board_offer_row.dart';
import '../widgets/board/board_view.dart';

/// Trang Offers (web `/offers`, mục "Offers" trên menu mobile): bảng service của chuyên gia —
/// tìm kiếm, bộ lọc, cuộn tải thêm. Trước là tab cạnh Requests ở trang chủ.
class OffersPage extends StatelessWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    return BlocProvider(
      create: (_) => getIt<BoardCubit<BoardOffer>>()..start(locale: locale),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colour.mutedWeb,
          appBar: BaseAppBar(title: LocaleKeys.homeMenuOffers.tr()),
          body: BoardView<BoardOffer>(
            kind: BoardKind.offers,
            itemBuilder: (context, o) =>
                BoardOfferRow(key: ValueKey(o.id), offer: o),
          ),
        ),
      ),
    );
  }
}
