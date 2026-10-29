part of 'home_bloc.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

final class HomeStarted extends HomeEvent {
  const HomeStarted();
}

/// Ô "Ask StrongBody" được / mất focus — focus mà chưa gõ → "Recent searches".
final class HomeComposerFocusChanged extends HomeEvent {
  final bool focused;

  const HomeComposerFocusChanged(this.focused);

  @override
  List<Object?> get props => [focused];
}

/// Đã tìm một từ khoá (gửi / chạm gợi ý) → lưu vào "Recent searches".
final class HomeSearchRecorded extends HomeEvent {
  final String text;

  const HomeSearchRecorded(this.text);

  @override
  List<Object?> get props => [text];
}

/// Chữ trong ô "Ask StrongBody" đổi → gợi ý theo chữ đó.
final class HomeQueryChanged extends HomeEvent {
  final String text;

  const HomeQueryChanged(this.text);

  @override
  List<Object?> get props => [text];
}

final class _HomeSuggestionsRequested extends HomeEvent {
  final String query;

  const _HomeSuggestionsRequested(this.query);

  @override
  List<Object?> get props => [query];
}
