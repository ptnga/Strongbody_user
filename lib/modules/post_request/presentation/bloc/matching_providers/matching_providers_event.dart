part of 'matching_providers_bloc.dart';

sealed class MatchingProvidersEvent extends Equatable {
  const MatchingProvidersEvent();

  @override
  List<Object?> get props => [];
}

final class MatchingProvidersStarted extends MatchingProvidersEvent {
  final String keyword;
  final ProviderRequestContext context;
  final List<ProviderEntity> initiallySelected;

  const MatchingProvidersStarted({
    required this.keyword,
    this.context = const ProviderRequestContext(),
    this.initiallySelected = const [],
  });

  @override
  List<Object?> get props => [keyword, context, initiallySelected];
}

final class MatchingProvidersKeywordSubmitted extends MatchingProvidersEvent {
  final String keyword;

  const MatchingProvidersKeywordSubmitted(this.keyword);

  @override
  List<Object?> get props => [keyword];
}

final class MatchingProvidersLoadMore extends MatchingProvidersEvent {
  const MatchingProvidersLoadMore();
}

/// Chọn / bỏ chọn provider (chế độ "Only providers I choose").
final class MatchingProvidersToggled extends MatchingProvidersEvent {
  final ProviderEntity provider;

  const MatchingProvidersToggled(this.provider);

  @override
  List<Object?> get props => [provider];
}

final class MatchingProvidersFilterToggled extends MatchingProvidersEvent {
  final ProviderFilter filter;

  const MatchingProvidersFilterToggled(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// "Clear filters" khi lọc không còn ai.
final class MatchingProvidersFiltersCleared extends MatchingProvidersEvent {
  const MatchingProvidersFiltersCleared();
}

/// Câu "refine by voice" (đã chuyển chữ) → đổi từ khoá / bật chip tương ứng.
final class MatchingProvidersRefined extends MatchingProvidersEvent {
  final String text;

  const MatchingProvidersRefined(this.text);

  @override
  List<Object?> get props => [text];
}

final class _MatchingProvidersExtrasRequested extends MatchingProvidersEvent {
  final ProviderEntity provider;

  const _MatchingProvidersExtrasRequested(this.provider);

  @override
  List<Object?> get props => [provider];
}
