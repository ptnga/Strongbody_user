import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../utils/app_logger.dart';

/// Bloc gọi [UseCase] nên extend class này và dùng [callApi] thay vì tự viết
/// try/catch + `Either.fold`.
abstract class BlocWithApi<E, S> extends Bloc<E, S> {
  BlocWithApi(super.initialState);

  static final Map<String, dynamic> _cache = {};

  Future<void> callApi<T, P>({
    required UseCase<T, P> useCase,
    P? param,
    required Future<void> Function(T data) onSuccess,
    required void Function(String errorMessage) onFailure,

    /// Nhận nguyên [Failure] để phân nhánh theo loại lỗi (404/401/network...)
    /// thay vì dò chuỗi trong message. Gọi trước [onFailure].
    void Function(Failure failure)? onFailureTyped,
    bool useCache = false,
  }) async {
    if (param == null && P != NoParams) {
      AppLogger.e('Params is required but not provided.');
      if (!isClosed) {
        onFailure(
          'An unexpected error occurred: Params is required but not provided.',
        );
      }
      return;
    }

    final checkedParam = param ?? const NoParams() as P;
    final cacheKey = '$T-${checkedParam.hashCode}';

    if (useCache) {
      final T? cachedData = _cache[cacheKey] as T?;
      if (cachedData != null) {
        if (isClosed) return;
        await onSuccess(cachedData);
        return;
      }
    }

    try {
      final result = await useCase.call(checkedParam);
      if (isClosed) return;
      await result.fold(
        (failure) {
          final message = failure.message.isNotEmpty
              ? failure.message
              : 'An unexpected error occurred';
          AppLogger.e(message);
          onFailureTyped?.call(failure);
          onFailure(message);
        },
        (T data) async {
          if (useCache) {
            _cache[cacheKey] = data;
          }
          await onSuccess(data);
        },
      );
    } catch (e) {
      AppLogger.e(e);
      if (isClosed) return;
      onFailure(e.toString());
    }
  }

  static void clearCache() {
    _cache.clear();
  }
}
