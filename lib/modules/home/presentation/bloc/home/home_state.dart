part of 'home_bloc.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final bool isLoggedIn;
  final String? userName;

  /// Số offer mới trên request của buyer; 0 = ẩn pill.
  final int newOffersCount;

  /// Gợi ý khi đang gõ; null = không gõ / câu dài → hiện lời chào + thẻ gợi ý.
  final TypingSuggestionSeed? typing;

  /// Ô nhập đang focus và từ khoá đã tìm (mới nhất trước).
  final bool composerFocused;
  final List<String> recentSearches;

  /// Focus mà chưa gõ → hiện "Recent searches" (như prototype).
  bool get showRecent =>
      composerFocused && typing == null && recentSearches.isNotEmpty;

  const HomeState({
    this.status = HomeStatus.initial,
    this.isLoggedIn = false,
    this.userName,
    this.newOffersCount = 0,
    this.typing,
    this.composerFocused = false,
    this.recentSearches = const [],
  });

  /// Coi `initial` như đang tải để frame đầu không hiện empty state.
  bool get isFirstLoad =>
      status == HomeStatus.initial || status == HomeStatus.loading;

  /// "Sarah Nguyen" → "SN"; "sarah" → "S".
  String get initials {
    final parts = (userName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  /// Tên gọi trong lời chào: từ đầu tiên của tên.
  String? get firstName {
    final name = userName?.trim();
    if (name == null || name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  HomeState copyWith({
    HomeStatus? status,
    bool? isLoggedIn,
    String? userName,
    bool clearUserName = false,
    TypingSuggestionSeed? typing,
    bool clearTyping = false,
    bool? composerFocused,
    List<String>? recentSearches,
    int? newOffersCount,
  }) {
    return HomeState(
      status: status ?? this.status,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userName: clearUserName ? null : (userName ?? this.userName),
      newOffersCount: newOffersCount ?? this.newOffersCount,
      typing: clearTyping ? null : (typing ?? this.typing),
      composerFocused: composerFocused ?? this.composerFocused,
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isLoggedIn,
    userName,
    newOffersCount,
    typing,
    composerFocused,
    recentSearches,
  ];
}
