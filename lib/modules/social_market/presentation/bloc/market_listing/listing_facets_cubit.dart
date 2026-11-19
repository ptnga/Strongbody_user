import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/market_category.dart';
import '../../../domain/entities/market_listing_entities.dart';
import '../../../domain/usecases/social_market_use_cases.dart';
import '../category_market/category_market_bloc.dart'
    show CategoryMarketBloc, SectionStatus;

class ListingFacetsState extends Equatable {
  final SectionStatus status;

  /// Category doanh nghiệp đang chọn (`?category=`) — chỉ khi thuộc nhãn của trang.
  final String? category;

  /// Chưa chọn category: hàng chip "All" + các category đang có service.
  final List<MarketBusinessCategory> chips;

  /// Đã chọn category: tên category (theo API) + các tab classification của nó.
  final MarketBusinessCategory? selected;
  final List<MarketClassificationFacet> tabs;

  const ListingFacetsState({
    this.status = SectionStatus.initial,
    this.category,
    this.chips = const [],
    this.selected,
    this.tabs = const [],
  });

  ListingFacetsState copyWith({
    SectionStatus? status,
    List<MarketBusinessCategory>? chips,
    MarketBusinessCategory? selected,
    List<MarketClassificationFacet>? tabs,
  }) => ListingFacetsState(
    status: status ?? this.status,
    category: category,
    chips: chips ?? this.chips,
    selected: selected ?? this.selected,
    tabs: tabs ?? this.tabs,
  );

  @override
  List<Object?> get props => [status, category, chips, selected, tabs];
}

/// Hàng lọc của listing service trang nhãn "Browse by need" (web `NeedCategoryChips`):
/// - chưa chọn category → chip "All" + các category của nhãn có service (dùng lại
///   request section của trang nhãn);
/// - đã chọn category thuộc nhãn → thanh tab service classification của category đó
///   (web `ClassificationTabs`), chỉ classification đang có service.
/// Lỗi → không hiện hàng lọc (lưới vẫn lọc đúng theo category).
class ListingFacetsCubit extends Cubit<ListingFacetsState> {
  final GetServicesByCategoryUseCase _getSections;
  final GetServiceClassificationsUseCase _getClassifications;

  ListingFacetsCubit({
    required GetServicesByCategoryUseCase getSections,
    required GetServiceClassificationsUseCase getClassifications,
  }) : _getSections = getSections,
       _getClassifications = getClassifications,
       super(const ListingFacetsState());

  /// Category hợp lệ của [scope] (thuộc nhãn) hoặc null.
  static String? validCategory(MarketPageScope scope, String? category) {
    final slug = category?.trim().toLowerCase();
    if (slug == null || slug.isEmpty) return null;
    return (scope.need?.services.contains(slug) ?? false) ? slug : null;
  }

  Future<void> load(MarketPageScope scope, String? category) async {
    final need = scope.need;
    if (need == null || need.services.isEmpty) {
      emit(const ListingFacetsState(status: SectionStatus.success));
      return;
    }
    final sub = validCategory(scope, category);
    emit(ListingFacetsState(status: SectionStatus.loading, category: sub));
    if (sub != null) {
      final result = await _getClassifications(sub);
      if (isClosed) return;
      result.fold(
        (_) => emit(state.copyWith(status: SectionStatus.failure)),
        (data) => emit(
          state.copyWith(
            status: SectionStatus.success,
            selected: data.category,
            // Category lạ → không có thanh tab. UI chỉ hiện tab có service (và tab đang
            // chọn, kể cả khi đã hết service).
            tabs: data.category == null ? const [] : data.list,
          ),
        ),
      );
      return;
    }
    final result = await _getSections((
      categories: need.services,
      per: CategoryMarketBloc.servicesPerSection,
    ));
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(status: SectionStatus.failure)),
      (sections) => emit(
        state.copyWith(
          status: SectionStatus.success,
          chips: [
            for (final s in sections)
              if (s.total > 0) s.category,
          ],
        ),
      ),
    );
  }
}
