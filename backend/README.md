# Wareeny VLM Backend

Minimal FastAPI service that fronts a self-hosted **Gemma 4** vision model and
streams answers to the app over Server-Sent Events. This is the **cloud tier** —
the fallback / heavy-task path. The on-device VLM is the main path (Phase F).

The app sends the tuned per-task prompt; the backend just relays image + prompt
to the model and streams tokens. No task logic lives here.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/vlm/generate` | Multimodal image + task prompt → SSE token stream |
| `GET` | `/health` | Liveness + which model is configured |
| `GET` | `/app-config` | Cloud model id, streaming flag, supported tasks |
| `GET` | `/model-manifest` | On-device model registry (Phase F install flow, stubbed) |

### `POST /vlm/generate`

Request (JSON):

```json
{
  "task": "read",
  "prompt": "<tuned system prompt from the app>",
  "image": "<base64 image bytes>",
  "model": "gemma4:e4b",
  "question": "optional, only for askImage"
}
```

Response: `text/event-stream` of

```
data: {"delta": "..."}
data: {"delta": "..."}
data: [DONE]
```

Errors stream as `data: {"error": "..."}` followed by `data: [DONE]`.

## Run

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# serve a vision-capable Gemma locally
ollama pull gemma4:e4b

cp .env.example .env   # edit if your Ollama lives elsewhere
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The Flutter dev config points at `http://localhost:8000` (`API_BASE_URL`). From a
physical phone, set `API_BASE_URL` to your machine's LAN IP when running the app:

```bash
flutter run --dart-define=API_BASE_URL=http://<your-ip>:8000
```

## Config

| Env | Default | Meaning |
| --- | --- | --- |
| `OLLAMA_URL` | `http://localhost:11434` | Where the model is served |
| `GEMMA_MODEL` | `gemma4:e4b` | Vision-capable Gemma tag |
| `APP_ENV` | `dev` | Reported by `/health` |
