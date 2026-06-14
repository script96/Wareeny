# API Specification

This document covers all external APIs: the FastAPI cloud backend, the Flutter-to-native platform channel contracts, and the internal VLM provider interface.

---

## Cloud Backend — FastAPI (`backend/main.py`)

Base URL:
- **Development:** `http://localhost:8000` (or `http://<LAN_IP>:8000` for physical device)
- **Production:** `https://api.wareeny.app`

The base URL is injected at Flutter build time via `--dart-define=API_BASE_URL=...`.

---

### POST /vlm/generate

Stream a VLM response for an image + task prompt.

**Request body (JSON):**

```json
{
  "task": "scan",
  "prompt": "<system prompt built by VlmPrompts for the given task>",
  "image": "<base64-encoded JPEG, longest edge ≤ 1024 px, quality 80>",
  "model": "gemma4:e4b",
  "question": null
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `task` | `string` | Yes | One of `scan`, `read`, `describeScene`, `inHand`, `currency`, `brand`, `askImage`. Controls the token budget. |
| `prompt` | `string` | Yes | The full system+user prompt assembled by `VlmPrompts` in the Flutter app. |
| `image` | `string` | Yes | Base64-encoded JPEG. Client downsizes to ≤ 1024 px longest edge before encoding. |
| `model` | `string` | No | Ollama model tag override. Defaults to the server's `GEMMA_MODEL` env var (`gemma4:e4b`). |
| `question` | `string` | No | The user's spoken question. Only meaningful for `askImage`; otherwise `null`. |

**Response:** `text/event-stream` (Server-Sent Events)

Each line is a JSON object prefixed with `data: `:

```
data: {"delta": "The document "}
data: {"delta": "says: Invoice "}
data: {"delta": "#4821."}
data: [DONE]
```

On error, one error event is emitted before `[DONE]`:

```
data: {"error": "model backend 503: service unavailable"}
data: [DONE]
```

**Token budget by task:**

| Task | `num_predict` |
|---|---|
| `scan` | 80 |
| `read` | 1200 |
| All others | 320 (default) |

**Headers returned:**

```
Content-Type: text/event-stream
Cache-Control: no-cache
X-Accel-Buffering: no
```

**Notes:**
- The backend sets Ollama `keep_alive` (default `30m`) so the model stays resident between calls. This eliminates the multi-second cold-load latency on subsequent scans.
- The `think` flag is set to `false` — Gemma 4's built-in reasoning is disabled because it consumes the token budget silently and returns an empty content field.

---

### GET /health

Liveness probe. Used by `CloudVlmProvider.isAvailable()` before every request.

**Response (200 OK):**

```json
{
  "status": "ok",
  "model": "gemma4:e4b",
  "env": "dev"
}
```

---

### GET /app-config

Client discovery endpoint. Returns the cloud tier's model ID and supported task list.

**Response (200 OK):**

```json
{
  "cloudModelId": "gemma4:e4b",
  "streaming": true,
  "tasks": ["read", "describeScene", "inHand", "currency", "brand", "askImage"]
}
```

---

### GET /model-manifest

On-device model registry. Stubbed for Phase F (on-device VLM installer flow).

**Response (200 OK):**

```json
{
  "models": [
    {
      "id": "wareeny-gemma-4-e4b",
      "name": "Gemma 4 E4B (on-device)",
      "capabilityClass": "high",
      "sizeBytes": 0,
      "checksum": "",
      "url": ""
    }
  ]
}
```

---

## Native Platform Channels

Channel contracts between the Flutter Dart layer and native Android (Kotlin) / iOS (Swift) code. All channel names are constants in `lib/shared/bridges/native_bridge_channels.dart`.

---

### Emergency SMS — `com.wareeny.bridge/emergency`

**Implemented in:** `android/app/src/main/kotlin/MainActivity.kt`

**Direction:** Dart → Android

**Method:** `sms.send`

**Arguments (Map):**

| Key | Type | Description |
|---|---|---|
| `phone` | `String` | E.164 phone number, e.g. `"+201234567890"` |
| `body` | `String` | SMS body text. Long messages are split automatically via `SmsManager.divideMessage()`. |

**Return:** `true` on success. Throws a platform exception with an error code on failure.

**Android version note:** Uses `SmsManager.createForSubscriptionId()` on API 31+ and the deprecated singleton on older versions.

**iOS:** Not implemented. The iOS side uses `flutter_phone_direct_caller` for the voice call and `url_launcher` with a `sms:` URI for messaging.

---

### Object Detection Events — `com.wareeny.bridge/object_detection_events`

**Direction:** Native → Dart (EventChannel)

**Payload per event (JSON-encoded map):**

```json
{
  "frameId": 42,
  "sourceWidth": 1280,
  "sourceHeight": 720,
  "timestamp": "2025-06-14T12:00:00.000Z",
  "inferenceMs": 32,
  "fps": 28.5,
  "detections": [
    {
      "label": "chair",
      "confidence": 0.87,
      "left": 120.0,
      "top": 200.0,
      "right": 400.0,
      "bottom": 550.0,
      "trackingId": "obj_7"
    }
  ]
}
```

---

### Local AI Runtime — `com.wareeny.bridge/local_ai_runtime`

**Direction:** Dart ↔ Native

**Methods (planned for Phase F):**

| Method | Arguments | Return | Description |
|---|---|---|---|
| `model.load` | `{ "registryName": String }` | `bool` | Load the on-device Gemma model. |
| `model.unload` | — | `void` | Release model memory. |
| `model.isAvailable` | — | `bool` | Check if a model is loaded and ready. |
| `inference.run` | `{ "prompt": String, "image": String }` | (see stream) | Start inference. |

**Streaming:** Token deltas are pushed via the companion EventChannel `com.wareeny.bridge/local_ai_runtime/stream`.

---

### Other Channels (Dart-side adapters only, native side TBD)

| Channel | Bridge file | Status |
|---|---|---|
| `com.wareeny.bridge/camera` | `camera_bridge.dart` | Delegated to Flutter `camera` package |
| `com.wareeny.bridge/audio_haptics` | `audio_haptics_bridge.dart` | Haptic control (vibration patterns) |
| `com.wareeny.bridge/battery_thermal` | `battery_thermal_bridge.dart` | Thermal state monitoring |
| `com.wareeny.bridge/file_download` | `file_download_bridge.dart` | On-device model file install |
| `com.wareeny.bridge/ocr` | Reserved | Future Arabic OCR (iOS Vision / Android ML Kit) |

---

## Internal VLM Provider Interface

Defined in `lib/shared/vlm/vlm_provider.dart`. Both `CloudVlmProvider` and `LocalVlmProvider` implement this interface.

```dart
abstract class VlmProvider {
  /// True if this tier is ready to serve requests right now.
  Future<bool> get isAvailable;

  /// Stream token deltas for the given request.
  /// The stream ends with a terminal [VlmResponse].
  Stream<VlmChunk> generate(VlmRequest request);
}
```

**Routing logic** (`lib/shared/vlm/model_router.dart`):

| Task | Primary tier | Fallback |
|---|---|---|
| `scan` | `localDevice` | `cloud` |
| `read` | `localDevice` | `cloud` |
| `inHand` | `localDevice` | `cloud` |
| `currency` | `localDevice` | `cloud` |
| `brand` | `localDevice` | `cloud` |
| `describeScene` | `cloud` | `localDevice` |
| `askImage` | `cloud` | `localDevice` |

If both tiers are unavailable, `VlmAssistant` emits a single `VlmChunk` with an appropriate localized error string and a terminal `VlmResponse` with `source: VlmSource.unavailable`.

---

## Image Contract (Flutter → Backend)

Before uploading, `CloudVlmProvider` encodes the captured image:

1. Load JPEG bytes from `imagePath`.
2. Decode with the `image` Dart package.
3. Resize so the longest edge is ≤ 1024 px (aspect-ratio preserved).
4. Re-encode as JPEG at quality 80.
5. Base64-encode and embed in the `image` field of the JSON body.

This keeps payloads under ~200 KB even for high-resolution camera captures.

---

## VLM Task Prompts

All prompts are in `lib/shared/vlm/vlm_prompts.dart`. The backend is prompt-agnostic — it relays whatever the app sends. Key design choices baked into the prompts:

- Never start a response with "I see" or "I can see".
- Speak results as if talking to the listener, not describing an image.
- `scan`: one sentence maximum with the key fact.
- `read`: faithful body text only, skip all page furniture (headers, footers, ads, nav UI).
- `currency` / `brand`: lead with the value or brand name, then one supporting detail.
- `askImage`: answer the user's question directly, no preamble.
