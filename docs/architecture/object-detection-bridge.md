# Object Detection Runtime

Navigation currently uses the on-device Google ML Kit base object detector in
stream mode. It receives frames from the same camera controller used by the
preview and publishes `ObjectDetectionFrame` values to the navigation engine.

This is the working fallback because the repository does not currently contain
a YOLO/LiteRT model asset. ML Kit supplies obstacle boxes and tracking IDs, but
its base classifier only has broad generic labels. A trained TFLite model can
replace the source in `ServiceRegistry` without changing the risk engine or
overlay.

## Future Native Contract

The reserved native YOLO/LiteRT adapter uses:

- method channel: `com.wareeny.bridge/object_detection`
- event channel: `com.wareeny.bridge/object_detection_events`
- start method: `objectDetection.start`
- stop method: `objectDetection.stop`

`objectDetection.start` receives:

```json
{"mode": "navigation"}
```

Each event must use source-frame pixel coordinates:

```json
{
  "frameId": 42,
  "timestampMs": 1781020800000,
  "imageWidth": 640,
  "imageHeight": 480,
  "rotationDegrees": 90,
  "mirrored": false,
  "inferenceTimeMs": 36,
  "fps": 12.5,
  "isLowLight": false,
  "detections": [
    {
      "trackingId": "17",
      "label": "chair",
      "confidence": 0.87,
      "box": {
        "left": 120,
        "top": 80,
        "right": 310,
        "bottom": 430
      }
    }
  ]
}
```

`rotationDegrees` is the clockwise rotation needed to align the source frame
with the displayed preview. `mirrored` is applied after rotation. The Flutter
mapper normalizes this data and applies the same center-crop projection used by
the camera preview.
