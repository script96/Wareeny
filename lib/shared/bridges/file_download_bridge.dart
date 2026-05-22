import 'package:flutter/services.dart';

import 'package:wareny/shared/bridges/native_bridge_channels.dart';

class FileDownloadRequest {
  const FileDownloadRequest({
    required this.url,
    required this.destinationFileName,
    required this.expectedSha256,
  });

  final String url;
  final String destinationFileName;
  final String expectedSha256;

  Map<String, Object?> toMap() {
    return {
      'url': url,
      'destinationFileName': destinationFileName,
      'expectedSha256': expectedSha256,
    };
  }
}

class FileDownloadBridge {
  const FileDownloadBridge()
    : _channel = const MethodChannel(NativeBridgeChannels.fileDownload);

  final MethodChannel _channel;

  static const enqueueMethod = 'download.enqueue';
  static const cancelMethod = 'download.cancel';

  Future<String?> enqueue(FileDownloadRequest request) {
    return _channel.invokeMethod<String>(enqueueMethod, request.toMap());
  }

  Future<void> cancel(String downloadId) {
    return _channel.invokeMethod<void>(cancelMethod, {
      'downloadId': downloadId,
    });
  }
}
