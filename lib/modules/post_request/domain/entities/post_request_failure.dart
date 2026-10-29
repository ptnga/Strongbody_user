import 'package:strongbody_buyer/core/base/failure.dart';

/// BE giới hạn số lần chuyển giọng nói (code 42914).
class SpeechRateLimitFailure extends Failure {
  SpeechRateLimitFailure(super.message, {super.statusCode});
}
