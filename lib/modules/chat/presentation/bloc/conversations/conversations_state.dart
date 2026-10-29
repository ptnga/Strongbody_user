part of 'conversations_bloc.dart';

enum ConversationsStatus { initial, loading, success, failure, signedOut }

class ConversationsState extends Equatable {
  final ConversationsStatus status;
  final List<ConversationEntity> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String query;

  /// Người tìm được chưa có hội thoại.
  final List<ChatUserEntity> people;
  final bool isSearching;

  const ConversationsState({
    this.status = ConversationsStatus.initial,
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.query = '',
    this.people = const [],
    this.isSearching = false,
  });

  bool get isFirstLoad =>
      status == ConversationsStatus.initial ||
      status == ConversationsStatus.loading;

  List<ConversationEntity> get visibleItems {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((c) => c.partnerName.toLowerCase().contains(q)).toList();
  }

  List<ChatUserEntity> get visiblePeople {
    final known = items.map((c) => c.partnerId).toSet();
    return people.where((p) => !known.contains(p.id)).toList();
  }

  ConversationsState copyWith({
    ConversationsStatus? status,
    List<ConversationEntity>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? query,
    List<ChatUserEntity>? people,
    bool? isSearching,
  }) {
    return ConversationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      query: query ?? this.query,
      people: people ?? this.people,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    page,
    hasMore,
    isLoadingMore,
    query,
    people,
    isSearching,
  ];
}
