import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';

import '../../../domain/entities/provider_entity.dart';
import '../../../domain/entities/provider_refine_query.dart';
import '../../../domain/entities/request_form_values.dart';
import '../../../domain/usecases/get_provider_extras_use_case.dart';
import '../../../domain/usecases/search_providers_use_case.dart';

part 'matching_providers_event.dart';
part 'matching_providers_state.dart';

/// "Browse matching providers": danh sách expert theo từ khoá nghề (`expert/balanced`),
/// bổ sung từng thẻ giá "from" / cách cung cấp / lịch rảnh, chip lọc lấy từ request,
/// "refine by voice", và chọn nhiều cho chế độ "Only providers I choose".
class MatchingProvidersBloc
    extends BlocWithApi<MatchingProvidersEvent, MatchingProvidersState> {
  final SearchProvidersUseCase _searchProviders;
  final GetProviderExtrasUseCase _getProviderExtras;

  static const _pageSize = 20;

  MatchingProvidersBloc({
    required SearchProvidersUseCase searchProviders,
    required GetProviderExtrasUseCase getProviderExtras,
  }) : _searchProviders = searchProviders,
       _getProviderExtras = getProviderExtras,
       super(const MatchingProvidersState()) {
    on<MatchingProvidersStarted>(_onStarted);
    on<MatchingProvidersKeywordSubmitted>(_onKeywordSubmitted);
    on<MatchingProvidersLoadMore>(_onLoadMore);
    on<MatchingProvidersToggled>(_onToggled);
    on<MatchingProvidersFilterToggled>(_onFilterToggled);
    on<MatchingProvidersFiltersCleared>(
      (event, emit) => emit(state.copyWith(activeFilters: const {})),
    );
    on<MatchingProvidersRefined>(_onRefined);
    on<_MatchingProvidersExtrasRequested>(_onExtrasRequested);
  }

  Future<void> _onStarted(
    MatchingProvidersStarted event,
    Emitter<MatchingProvidersState> emit,
  ) async {
    emit(
      state.copyWith(
        keyword: event.keyword,
        selected: event.initiallySelected,
        context: event.context,
        // Mặc định bật cách nhận + thời gian của request (như mockup).
        activeFilters: {
          if (event.context.deliveryTypes.isNotEmpty) ProviderFilter.delivery,
          if (event.context.startDate != null) ProviderFilter.dates,
        },
      ),
    );
    await _load(emit, page: 1);
  }

  Future<void> _onKeywordSubmitted(
    MatchingProvidersKeywordSubmitted event,
    Emitter<MatchingProvidersState> emit,
  ) async {
    final keyword = event.keyword.trim();
    if (keyword.isEmpty || keyword == state.keyword) return;
    AppAnalytics.capture(AnalyticsEvents.providersKeywordEdited, {
      'keyword': keyword,
    });
    emit(state.copyWith(keyword: keyword, items: const [], page: 1));
    await _load(emit, page: 1);
  }

  Future<void> _onLoadMore(
    MatchingProvidersLoadMore event,
    Emitter<MatchingProvidersState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.isFirstLoad) return;
    emit(state.copyWith(isLoadingMore: true));
    await _load(emit, page: state.page + 1);
  }

  Future<void> _load(
    Emitter<MatchingProvidersState> emit, {
    required int page,
  }) async {
    final keyword = state.keyword;
    if (keyword.isEmpty) {
      emit(
        state.copyWith(status: MatchingProvidersStatus.success, hasMore: false),
      );
      return;
    }
    if (page == 1) {
      emit(state.copyWith(status: MatchingProvidersStatus.loading));
    }
    await callApi(
      useCase: _searchProviders,
      param: SearchProvidersParams(
        keyword: keyword,
        page: page,
        limit: _pageSize,
      ),
      onSuccess: (result) async {
        // Bỏ kết quả của từ khoá cũ nếu người dùng đã tìm từ khác.
        if (keyword != state.keyword) return;
        emit(
          state.copyWith(
            status: MatchingProvidersStatus.success,
            items: page == 1 ? result.items : [...state.items, ...result.items],
            total: result.total,
            page: page,
            hasMore: page < result.totalPage,
            isLoadingMore: false,
          ),
        );
        if (page == 1) {
          AppAnalytics.capture(AnalyticsEvents.providersResultsLoaded, {
            'keyword': keyword,
            'total': result.total,
            'active_filters': state.activeFilters.map((f) => f.name).join(','),
          });
        }
        _fillFilteredPage();
        for (final provider in result.items) {
          if (!state.extras.containsKey(provider.id)) {
            add(_MatchingProvidersExtrasRequested(provider));
          }
        }
      },
      onFailure: (message) => emit(
        state.copyWith(
          status: page == 1 ? MatchingProvidersStatus.failure : state.status,
          errorMessage: message,
          isLoadingMore: false,
        ),
      ),
    );
  }

  /// Bộ lọc ẩn gần hết trang đã tải → danh sách không cuộn được nên scroll không gọi
  /// load-more; tự tải trang sau để không báo "không có provider" oan.
  void _fillFilteredPage() {
    if (state.hasMore &&
        !state.isLoadingMore &&
        state.visibleItems.length < _minVisible) {
      add(const MatchingProvidersLoadMore());
    }
  }

  static const _minVisible = 6;

  Future<void> _onExtrasRequested(
    _MatchingProvidersExtrasRequested event,
    Emitter<MatchingProvidersState> emit,
  ) async {
    await callApi(
      useCase: _getProviderExtras,
      param: event.provider,
      onSuccess: (extras) async => emit(
        state.copyWith(extras: {...state.extras, event.provider.id: extras}),
      ),
      onFailure: (_) {},
    );
  }

  void _onToggled(
    MatchingProvidersToggled event,
    Emitter<MatchingProvidersState> emit,
  ) {
    final exists = state.isSelected(event.provider);
    AppAnalytics.capture(AnalyticsEvents.providerSelectionToggled, {
      'provider_id': event.provider.userId,
      'selected': !exists,
    });
    emit(
      state.copyWith(
        selected: exists
            ? state.selected
                  .where((p) => p.userId != event.provider.userId)
                  .toList()
            : [...state.selected, event.provider],
      ),
    );
  }

  void _onFilterToggled(
    MatchingProvidersFilterToggled event,
    Emitter<MatchingProvidersState> emit,
  ) {
    final active = {...state.activeFilters};
    final on = !active.remove(event.filter);
    if (on) active.add(event.filter);
    AppAnalytics.capture(AnalyticsEvents.providersFilterToggled, {
      'filter': event.filter.name,
      'active': on,
    });
    emit(state.copyWith(activeFilters: active));
    _fillFilteredPage();
  }

  Future<void> _onRefined(
    MatchingProvidersRefined event,
    Emitter<MatchingProvidersState> emit,
  ) async {
    final query = ProviderRefineQuery.parse(event.text);
    if (query.isEmpty) return;
    final active = {...state.activeFilters};
    var context = state.context;
    if (query.languageCode != null) {
      context = context.copyWith(languageCode: query.languageCode);
      active.add(ProviderFilter.language);
    }
    if (query.maxBudget != null) {
      context = context.copyWith(maxBudget: query.maxBudget);
      active.add(ProviderFilter.budget);
    }
    if (query.topRated) active.add(ProviderFilter.topRated);
    AppAnalytics.capture(AnalyticsEvents.providersRefinedByVoice, {
      'language': query.languageCode,
      'max_budget': query.maxBudget,
      'top_rated': query.topRated,
      'keyword': query.keyword,
    });
    emit(state.copyWith(context: context, activeFilters: active));

    final keyword = query.keyword;
    if (keyword != null && keyword != state.keyword) {
      emit(state.copyWith(keyword: keyword, items: const [], page: 1));
      await _load(emit, page: 1);
    }
  }
}
