part of 'post_request_flow_bloc.dart';

sealed class PostRequestFlowEvent extends Equatable {
  const PostRequestFlowEvent();

  @override
  List<Object?> get props => [];
}

/// Mở màn "Post a request" với input vừa gửi (text / bản ghi / bản nháp có sẵn).
final class PostRequestFlowStarted extends PostRequestFlowEvent {
  final PostRequestFlowArgs args;

  /// Ngôn ngữ giao diện — AI soạn theo ngôn ngữ này, Working language mặc định là nó.
  final String locale;

  const PostRequestFlowStarted({required this.args, required this.locale});

  @override
  List<Object?> get props => [
    args.text,
    args.audioPath,
    args.draft,
    args.prefill,
    args.sellerUserIds,
    locale,
  ];
}

final class PostRequestFlowValuesChanged extends PostRequestFlowEvent {
  final RequestFormValues values;

  const PostRequestFlowValuesChanged(this.values);

  @override
  List<Object?> get props => [values];
}

/// Bỏ voice note gửi kèm (vẫn "Undo" được).
final class PostRequestFlowVoiceRemoved extends PostRequestFlowEvent {
  const PostRequestFlowVoiceRemoved();
}

final class PostRequestFlowVoiceRestored extends PostRequestFlowEvent {
  const PostRequestFlowVoiceRestored();
}

final class PostRequestFlowSubmitted extends PostRequestFlowEvent {
  const PostRequestFlowSubmitted();
}

final class PostRequestFlowNoticeConsumed extends PostRequestFlowEvent {
  const PostRequestFlowNoticeConsumed();
}

/// Danh sách tiền tệ tải xong (nội bộ).
final class _PostRequestFlowCurrenciesLoaded extends PostRequestFlowEvent {
  final List<CurrencyOption> currencies;

  const _PostRequestFlowCurrenciesLoaded(this.currencies);

  @override
  List<Object?> get props => [currencies];
}

/// Nhịp thanh tiến trình (nội bộ).
final class _PostRequestFlowTicked extends PostRequestFlowEvent {
  const _PostRequestFlowTicked();
}
