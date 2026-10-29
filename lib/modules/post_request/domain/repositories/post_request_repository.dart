import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../entities/my_request_entity.dart';
import '../entities/provider_entity.dart';
import '../entities/request_draft_entity.dart';
import '../entities/request_form_values.dart';

abstract class PostRequestRepository {
  /// Giọng nói → text (`POST /speech-to-text`, fallback route cũ của web).
  Future<Either<Failure, String>> transcribeAudio(String audioPath);

  /// Text → giá trị form (API route web `/api/ai/request-draft`).
  Future<Either<Failure, RequestDraftEntity>> draftRequest({
    required String text,
    required String locale,
  });

  /// Đăng request. `sellerUserIds` rỗng → `POST /buyer/request` (mọi provider phù hợp);
  /// có id → `POST /buyer/request/to-seller` cho từng seller. Trả về status BE (`active` = đã lên).
  Future<Either<Failure, String?>> createBuyerRequest({
    required int userId,
    required RequestFormValues values,
    RequestAssistantMeta? assistant,
    List<int> sellerUserIds = const [],

    /// Gửi riêng từng provider: báo seller đã nhận để lần thử lại không gửi trùng.
    void Function(int sellerUserId)? onSellerPosted,
  });

  /// Giá "from", cách cung cấp, lịch rảnh của một provider (service + profile chi tiết).
  Future<Either<Failure, ProviderExtras>> getProviderExtras(
    ProviderEntity provider,
  );

  /// Provider khớp từ khoá nghề (`GET /user/strongbodyai/expert/balanced?keyword=`).
  Future<Either<Failure, ProviderPage>> searchProviders({
    required String keyword,
    int page = 1,
    int limit = 20,
  });

  /// Request của buyer (`GET /user/requests`).
  Future<Either<Failure, MyRequestPage>> getMyRequests({
    required int userId,
    int page = 1,
    int limit = 20,
  });

  /// Offer provider đã gửi cho một request.
  Future<Either<Failure, List<RequestOfferEntity>>> getRequestOffers(
    int requestId,
  );
}
