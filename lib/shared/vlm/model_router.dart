// ignore_for_file: prefer_initializing_formals

import 'package:wareeny/shared/vlm/vlm_provider.dart';
import 'package:wareeny/shared/vlm/vlm_task.dart';

/// Task-aware routing policy. Returns the providers to try, in preference order.
///
/// - `scan`, `read` → on-device first (private, offline), cloud fallback when
///   the local model is missing/unsupported and network is up.
/// - `askImage`, `describeScene` → cloud first (heavier reasoning), local fallback
///   when offline.
///
/// If every provider in the list is unavailable, the request is `unavailable`
/// (the accepted gap — no literal-OCR fallback). The actual availability check
/// and fallback execution happen in `VlmAssistant`; this class is pure policy.
class ModelRouter {
  const ModelRouter({required VlmProvider local, required VlmProvider cloud})
    : _local = local,
      _cloud = cloud;

  final VlmProvider _local;
  final VlmProvider _cloud;

  /// Providers to attempt for [task], in order of preference.
  List<VlmProvider> providersFor(VlmTask task) => switch (task) {
    VlmTask.scan || VlmTask.read => [_local, _cloud],
    VlmTask.askImage || VlmTask.describeScene => [_cloud, _local],
  };
}
