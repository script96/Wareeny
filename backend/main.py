"""Wareeny cloud VLM backend.

Minimal FastAPI service that fronts a self-hosted Gemma 4 vision model and
streams answers back to the app over Server-Sent Events. The Flutter
`CloudVlmProvider` talks to `POST /vlm/generate`; the on-device tier is the main
path and this is the fallback / heavy-task tier.

The model is served by Ollama (default) running a vision-capable Gemma. Point it
elsewhere with env vars (see `.env.example`). Nothing here is task-specific — the
app sends the tuned per-task prompt; this just relays image + prompt and streams
tokens.
"""

import json
import os

import httpx
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
GEMMA_MODEL = os.getenv("GEMMA_MODEL", "gemma4:e4b")
APP_ENV = os.getenv("APP_ENV", "dev")

# Default output cap; overridable per task below. Spoken answers are short, but a
# full document READ needs room so it isn't truncated mid-page.
NUM_PREDICT = int(os.getenv("NUM_PREDICT", "320"))
# Per-task output budgets. `scan` is a short identification (object, or a money
# total + breakdown of several notes — needs more than a one-liner); `read` reads
# a whole document.
NUM_PREDICT_BY_TASK = {
    "scan": int(os.getenv("NUM_PREDICT_SCAN", "200")),
    "read": int(os.getenv("NUM_PREDICT_READ", "1200")),
}

app = FastAPI(title="Wareeny VLM Backend")


class VlmGenerateRequest(BaseModel):
    task: str
    prompt: str
    image: str  # base64-encoded image bytes
    model: str | None = None
    question: str | None = None


def _sse(data: dict) -> str:
    return f"data: {json.dumps(data, ensure_ascii=False)}\n\n"


async def _stream_gemma(req: VlmGenerateRequest):
    """Stream token deltas from Ollama's chat API as SSE lines."""
    payload = {
        "model": req.model or GEMMA_MODEL,
        "messages": [
            {"role": "user", "content": req.prompt, "images": [req.image]}
        ],
        "stream": True,
        # Gemma 4 is a *thinking* model: left on, it spends the token budget on
        # hidden reasoning and returns an empty `content`. We only speak the
        # answer, so disable thinking — also faster (no reasoning tokens).
        "think": False,
        # Keep the model resident between calls so we don't pay the multi-second
        # reload on every scan (cold reload dominated first-token latency).
        "keep_alive": os.getenv("OLLAMA_KEEP_ALIVE", "30m"),
        # Output budget by task: a one-line gist for `scan`, a full read for
        # `read`, the default for everything else.
        "options": {"num_predict": NUM_PREDICT_BY_TASK.get(req.task, NUM_PREDICT)},
    }
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(120.0)) as client:
            async with client.stream(
                "POST", f"{OLLAMA_URL}/api/chat", json=payload
            ) as resp:
                if resp.status_code != 200:
                    body = await resp.aread()
                    yield _sse({"error": f"model backend {resp.status_code}: {body.decode()[:200]}"})
                    yield "data: [DONE]\n\n"
                    return
                async for line in resp.aiter_lines():
                    if not line.strip():
                        continue
                    chunk = json.loads(line)
                    delta = chunk.get("message", {}).get("content", "")
                    if delta:
                        yield _sse({"delta": delta})
                    if chunk.get("done"):
                        break
    except (httpx.HTTPError, OSError) as exc:
        yield _sse({"error": f"model backend unreachable: {exc}"})
    yield "data: [DONE]\n\n"


@app.post("/vlm/generate")
async def vlm_generate(req: VlmGenerateRequest):
    return StreamingResponse(
        _stream_gemma(req),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@app.get("/health")
def health():
    return {"status": "ok", "model": GEMMA_MODEL, "env": APP_ENV}


@app.get("/app-config")
def app_config():
    return {
        "cloudModelId": GEMMA_MODEL,
        "streaming": True,
        "tasks": ["scan", "read", "describeScene", "askImage"],
    }


@app.get("/model-manifest")
def model_manifest():
    # On-device model registry for the Phase F install flow. Stubbed for now.
    return {
        "models": [
            {
                "id": "wareeny-gemma-4-e4b",
                "name": "Gemma 4 E4B (on-device)",
                "capabilityClass": "high",
                "sizeBytes": 0,
                "checksum": "",
                "url": "",
            }
        ]
    }
