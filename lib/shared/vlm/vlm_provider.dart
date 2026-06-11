import 'package:wareeny/shared/vlm/vlm_models.dart';

/// Thrown by a [VlmProvider] when it cannot serve a request (no model, no
/// network, native runtime missing). The [ModelRouter] catches this and tries
/// the fallback tier; if every tier throws, the request is `unavailable`.
class VlmProviderUnavailable implements Exception {
  const VlmProviderUnavailable(this.reason);
  final String reason;

  @override
  String toString() => 'VlmProviderUnavailable: $reason';
}

/// A single tier that can turn an image + task into a streamed spoken answer.
/// One concrete provider per tier: [VlmSource.localDevice] and [VlmSource.cloud].
///
/// Screens and controllers must NOT call providers directly — they go through
/// `VlmAssistant` and the `ModelRouter` (see `RULES.MD`).
abstract class VlmProvider {
  /// Which tier this provider represents.
  VlmSource get source;

  /// Cheap readiness probe used by the router to pick a tier. Should not throw;
  /// returns false when this tier can't currently serve requests.
  Future<bool> isAvailable();

  /// Streams the answer as it is generated. The first emitted [VlmChunk] has
  /// `isFirst == true`. Throws [VlmProviderUnavailable] if the request cannot be
  /// served (so the router can fall back).
  Stream<VlmChunk> generate(VlmRequest request);
}
