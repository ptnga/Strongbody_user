import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../repositories/post_request_repository.dart';

class TranscribeAudioParams extends Equatable {
  final String audioPath;

  const TranscribeAudioParams(this.audioPath);

  @override
  List<Object?> get props => [audioPath];
}

class TranscribeAudioUseCase implements UseCase<String, TranscribeAudioParams> {
  final PostRequestRepository _repository;

  TranscribeAudioUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(TranscribeAudioParams params) =>
      _repository.transcribeAudio(params.audioPath);
}
