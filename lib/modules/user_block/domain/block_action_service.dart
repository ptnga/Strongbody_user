import 'package:strongbody_buyer/core/streams/user_block_event_bus.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';

import 'entities/user_block_error.dart';
import 'repositories/user_block_repository.dart';
import 'usecases/block_user_use_case.dart';
import 'usecases/unblock_user_use_case.dart';

/// Chặn / bỏ chặn kèm chính sách idempotent, dùng chung cho mọi nơi gọi.
///
/// "Đã chặn rồi thì coi như thành công" là quyết định sản phẩm — gom một chỗ.
/// Class thường (không Cubit) vì nơi gọi chỉ `await` một lần rồi tự cập nhật UI.
class BlockActionService {
  const BlockActionService({
    required BlockUserUseCase blockUser,
    required UnblockUserUseCase unblockUser,
    required UserBlockRepository repository,
  }) : _blockUser = blockUser,
       _unblockUser = unblockUser,
       _repository = repository;

  final BlockUserUseCase _blockUser;
  final UnblockUserUseCase _unblockUser;
  final UserBlockRepository _repository;

  /// `true` nghĩa là người đó hiện đang bị chặn — kể cả khi server báo "đã chặn
  /// từ trước".
  Future<bool> block(int userId, {String? reason}) async {
    final result = await _blockUser(
      BlockUserParams(userId: userId, reason: reason),
    );

    return result.fold(
      (failure) async {
        final kind = failure is UserBlockFailure
            ? failure.kind
            : UserBlockError.unknown;

        if (kind == UserBlockError.alreadyBlocked) {
          final recordId = await _repository.resolveBlockRecordId(userId);
          _emitBlocked(userId, recordId ?? 0);
          return true;
        }

        AppLogger.e('Block $userId failed (${kind.name}): ${failure.message}');
        return false;
      },
      (block) async {
        _emitBlocked(userId, block.blockRecordId);
        return true;
      },
    );
  }

  /// `true` nghĩa là người đó hiện KHÔNG bị chặn.
  Future<bool> unblock({
    required int userId,
    required int blockRecordId,
  }) async {
    final result = await _unblockUser(
      UnblockUserParams(blockRecordId: blockRecordId),
    );

    return result.fold(
      (failure) {
        final kind = failure is UserBlockFailure
            ? failure.kind
            : UserBlockError.unknown;

        // Bản ghi không còn / không thuộc mình — cả hai đều nghĩa là người đó
        // hiện không bị mình chặn.
        if (kind == UserBlockError.blockNotFound ||
            kind == UserBlockError.notMyBlock) {
          UserBlockEventBus.emit(UserUnblocked(userId));
          return true;
        }

        AppLogger.e(
          'Unblock $userId failed (${kind.name}): ${failure.message}',
        );
        return false;
      },
      (_) {
        UserBlockEventBus.emit(UserUnblocked(userId));
        return true;
      },
    );
  }

  /// Dò id bản ghi block khi chưa biết (vd "đã chặn từ trước").
  Future<int?> resolveBlockRecordId(int userId) =>
      _repository.resolveBlockRecordId(userId);

  void _emitBlocked(int userId, int blockRecordId) => UserBlockEventBus.emit(
    UserBlocked(userId: userId, blockRecordId: blockRecordId),
  );
}
