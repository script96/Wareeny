# Hosting Gemma 4 for Wareeny

The Wareeny backend needs a **multimodal** (vision + text) Gemma 4 model that
accepts base64 images and streams token deltas. This guide covers your options
and how to run each one.

---

## Is Ollama the Best Option?

**Short answer: yes, for development and demo. vLLM for production.**

| | Ollama | vLLM | llama.cpp | Google Cloud |
|---|---|---|---|---|
| Setup difficulty | Easy (5 min) | Medium | Medium | Hard |
| GPU required | Optional | Recommended | No | No (managed) |
| Vision support | ✅ Gemma 4 | ✅ | ✅ | ✅ |
| Streaming SSE | ✅ | ✅ | ✅ | ✅ |
| Cost | Free | Free | Free | Paid |
| Best for | Dev / demo | Production | CPU-only | If you need uptime |

**Use Ollama.** It is the fastest path to a working demo, fully free, handles
vision natively, and the backend already speaks its API.

---

## Gemma 4 Model Sizes

All multimodal (accept images). Pick based on your hardware:

| Tag | VRAM needed | Speed | Quality |
|---|---|---|---|
| `gemma4:e4b` | ~4 GB GPU or CPU-ok | Fast | Good for reading/labels |
| `gemma4:12b` | ~10 GB GPU | Medium | Better reasoning |
| `gemma4:27b` | ~20 GB GPU | Slow | Best quality |

For a **phone demo on your laptop**, `gemma4:e4b` is the right pick.

---

## Option 1 — Ollama (Recommended)

### Install

**macOS:**
```bash
brew install ollama
```

Or download the desktop app from [ollama.com](https://ollama.com).

**Linux:**
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Windows:** download the installer from [ollama.com](https://ollama.com).

### Pull Gemma 4

```bash
ollama pull gemma4:e4b
```

This downloads ~3–4 GB. Wait for it to finish.

Verify the model is vision-capable:
```bash
ollama show gemma4:e4b | grep -i vision
# should print something like: vision: true
```

### Run the Wareeny Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Ollama starts automatically as a background service after install.
# If it isn't running, start it manually:
ollama serve &

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Check it works:
```bash
curl http://localhost:8000/health
# → {"status":"ok","model":"gemma4:e4b","env":"dev"}
```

### Connect from Your Phone

Your phone and laptop must be on the **same Wi-Fi**.

1. Find your laptop's LAN IP:
   - macOS/Linux: `ifconfig | grep "inet " | grep -v 127`
   - Windows: `ipconfig` → look for IPv4 under Wi-Fi adapter
2. Run Flutter with that IP:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:8000
   ```

Example: `flutter run --dart-define=API_BASE_URL=http://192.168.1.38:8000`

---

## Option 2 — vLLM (Production / Better GPU)

Use this if you have a dedicated GPU server or want to handle concurrent users.

### Requirements

- NVIDIA GPU with 8 GB+ VRAM (for `gemma4:e4b`)
- CUDA 12.1+

### Install and Run

```bash
pip install vllm

python -m vllm.entrypoints.openai.api_server \
  --model google/gemma-4-e4b-it \
  --tokenizer google/gemma-4-e4b-it \
  --port 11434 \
  --dtype bfloat16
```

Then update `.env`:
```
OLLAMA_URL=http://localhost:11434
GEMMA_MODEL=google/gemma-4-e4b-it
```

You need to also update `backend/main.py` to target the vLLM OpenAI-compatible
`/v1/chat/completions` endpoint instead of Ollama's `/api/chat`. The payload
format is different.

---

## Option 3 — llama.cpp (No GPU)

Use this if you only have a CPU (slow but works for demo).

```bash
# Install
pip install llama-cpp-python[server]

# Download the GGUF version of Gemma 4 from HuggingFace
# Search for "gemma-4-e4b gguf" on huggingface.co

python -m llama_cpp.server \
  --model ~/Downloads/gemma-4-e4b.Q4_K_M.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --n_ctx 4096
```

Same backend-URL change as vLLM above (OpenAI-compatible endpoint).

---

## Troubleshooting

**`/health` returns 200 but generation fails:**
- Check Ollama is running: `ollama list` — model should appear.
- Check model is vision-capable: `ollama show gemma4:e4b`.
- Check Ollama logs: `journalctl -u ollama` (Linux) or the Ollama app logs (Mac).

**Phone can't reach the server:**
- Confirm same Wi-Fi.
- Disable laptop firewall temporarily or add a rule for port 8000.
- Test from the phone browser: `http://<laptop-ip>:8000/health` should return JSON.

**Out of VRAM:**
- Try `gemma4:e4b` instead of a larger model.
- On Mac with Apple Silicon, Ollama uses unified memory — 8 GB M-chip handles `gemma4:e4b` well.

**Slow first response (> 20 seconds):**
- Normal — first call loads the model into memory. Subsequent calls are faster.
- The `isThinking` pill in the app covers this latency.
