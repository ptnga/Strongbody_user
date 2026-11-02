import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/market_inquiry.dart';
import '../../../domain/usecases/social_market_use_cases.dart';

enum InquiryStatus { idle, sending, success, failure }

class InquiryState extends Equatable {
  final InquiryStatus status;

  /// User id người nhận (mở chat khi gửi xong).
  final int? recipientUserId;

  const InquiryState({this.status = InquiryStatus.idle, this.recipientUserId});

  @override
  List<Object?> get props => [status, recipientUserId];
}

/// Popup "Send your request" của card service / offer (web `InquiryDialog`).
class InquiryCubit extends Cubit<InquiryState> {
  final SendInquiryUseCase _sendInquiry;

  InquiryCubit({required SendInquiryUseCase sendInquiry})
    : _sendInquiry = sendInquiry,
      super(const InquiryState());

  Future<void> send(MarketInquiry inquiry) async {
    if (state.status == InquiryStatus.sending) return;
    emit(const InquiryState(status: InquiryStatus.sending));
    final result = await _sendInquiry(inquiry);
    if (isClosed) return;
    result.fold(
      (_) => emit(const InquiryState(status: InquiryStatus.failure)),
      (recipient) => emit(
        InquiryState(status: InquiryStatus.success, recipientUserId: recipient),
      ),
    );
  }
}
