part of 'post_request_flow_bloc.dart';

sealed class PostRequestFlowEvent extends Equatable {
  const PostRequestFlowEvent();

  @override
  List<Object?> get props => [];
}

/// Vào "Here's what I heard": (chuyển chữ nếu cần) → AI phân tích → đếm provider phù hợp.
final class PostRequestFlowStarted extends PostRequestFlowEvent {
  final PostRequestFlowArgs args;
  final String locale;

  const PostRequestFlowStarted({required this.args, required this.locale});

  @override
  List<Object?> get props => [
    args.text,
    args.voicePath,
    args.browseOnly,
    locale,
  ];
}

/// Người dùng sửa form ở màn Review.
final class PostRequestFlowValuesChanged extends PostRequestFlowEvent {
  final RequestFormValues values;

  const PostRequestFlowValuesChanged(this.values);

  @override
  List<Object?> get props => [values];
}

final class PostRequestFlowVisibilityChanged extends PostRequestFlowEvent {
  final RequestVisibility visibility;

  const PostRequestFlowVisibilityChanged(this.visibility);

  @override
  List<Object?> get props => [visibility];
}

/// Chọn xong danh sách provider (chế độ "Only providers I choose").
final class PostRequestFlowProvidersSelected extends PostRequestFlowEvent {
  final List<ProviderEntity> providers;

  const PostRequestFlowProvidersSelected(this.providers);

  @override
  List<Object?> get props => [providers];
}

/// Bỏ voice note khỏi request (nút thùng rác ở màn Review).
/// Sửa "Category" ngay ở thẻ "I understood".
final class PostRequestFlowCategoryChanged extends PostRequestFlowEvent {
  final int categoryId;

  const PostRequestFlowCategoryChanged(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

/// Thùng rác ở thẻ voice note: bỏ voice khỏi request, thẻ chuyển sang "Undo remove".
final class PostRequestFlowVoiceRemoved extends PostRequestFlowEvent {
  const PostRequestFlowVoiceRemoved();
}

/// "Undo remove": gắn lại voice note vừa xoá.
final class PostRequestFlowVoiceRestored extends PostRequestFlowEvent {
  const PostRequestFlowVoiceRestored();
}

final class PostRequestFlowSubmitted extends PostRequestFlowEvent {
  const PostRequestFlowSubmitted();
}

final class PostRequestFlowNoticeConsumed extends PostRequestFlowEvent {
  const PostRequestFlowNoticeConsumed();
}
