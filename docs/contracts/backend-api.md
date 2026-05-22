# Backend API Contract

Base path: `/`

## `GET /health`

Returns service health and configured upstream status.

## `GET /app-config`

Returns app runtime defaults such as:

- default routing preference
- battery thresholds
- thermal downgrade thresholds
- enabled feature flags

## `GET /model-manifest`

Returns the downloadable local model catalog and device-tier mapping.

## `POST /model-download-ticket`

Creates a download ticket for a model artifact.

Request body:

```json
{
  "model_id": "gemma-local-e2b",
  "device_tier": "medium",
  "platform": "android"
}
```

Response body:

```json
{
  "model_id": "gemma-local-e2b",
  "download_url": "https://...",
  "checksum_sha256": "abc123",
  "expires_at": "2026-05-22T12:00:00Z"
}
```

## `POST /llm/generate`

Cloud-only LLM generation endpoint backed by `Gemma 4 E4B`.

The mobile app should call this only after its own routing decision selects `cloud`.

## `POST /in-hand/detect`

Proxy endpoint to the existing Python in-hand service.

Accepts multipart file upload.

Response returns:

- label
- confidence
- provider
- latency
