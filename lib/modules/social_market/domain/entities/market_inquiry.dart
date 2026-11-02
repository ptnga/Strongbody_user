import 'package:equatable/equatable.dart';

/// Loại item được hỏi — `target_type` của inquiry và `type` của tin nhắn card.
enum InquiryKind { service, offer }

/// Một lần "Send Inquiry" / "I want this offer" (web `useSendInquiry`): 1 inquiry
/// (backend tạo kèm request private cho seller) + card + lời nhắn vào kênh chat.
class MarketInquiry extends Equatable {
  final InquiryKind kind;
  final int itemId;
  final int recipientUserId;
  final String content;

  /// Payload card đính kèm vào tin nhắn (`{type: kind, [kind]: cardData}`).
  final Map<String, dynamic> cardData;
  final double? budgetFrom;
  final double? budgetTo;
  final String budgetCurrency;

  /// remote | at_home | at_clinic | all.
  final String? deliveryType;

  /// JSON `{mon:[{from,to}]}`.
  final String? schedule;

  /// ISO 8601 (UTC).
  final String? deadline;
  final List<String> attachmentPaths;
  final String? itemTitle;
  final String? itemImage;
  final String? itemPrice;

  const MarketInquiry({
    required this.kind,
    required this.itemId,
    required this.recipientUserId,
    required this.content,
    required this.cardData,
    this.budgetFrom,
    this.budgetTo,
    this.budgetCurrency = 'USD',
    this.deliveryType,
    this.schedule,
    this.deadline,
    this.attachmentPaths = const [],
    this.itemTitle,
    this.itemImage,
    this.itemPrice,
  });

  @override
  List<Object?> get props => [kind, itemId, recipientUserId, content];
}
