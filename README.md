# Local RAG Knowledge Base

A fully local, self-hosted Retrieval-Augmented Generation (RAG) system. Upload documents (PDF or text), ask questions about them, and get answers grounded in your own files — all running on your own machine, no cloud services, no API keys, no data leaving your computer.

Built with FastAPI, ChromaDB, Ollama, and Streamlit.

## Features

- Ingest raw text or PDF documents
- Ask questions with streaming answers
- Per-document isolation (no cross-contamination between unrelated documents)
- Choose any locally-installed Ollama model
- Optional local benchmark logging
- Fully Dockerized — one command to run the whole stack

## Prerequisites

Before running this project, you need:

1. **Docker** and **Docker Compose** installed
2. **[Ollama](https://ollama.com/download)** installed and running on your host machine (not inside Docker)
3. Pull the required embedding model (this is hardcoded and required for ingestion to work):
   ```bash
   ollama pull nomic-embed-text
   ```
4. Pull at least one chat model of your choice, for example:
   ```bash
   ollama pull qwen2.5-coder:7b
   ```

### Linux-specific setup (important)

By default, Ollama on Linux only listens on `127.0.0.1`, which makes it unreachable from inside Docker containers. You need to configure it to listen on all interfaces:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

If Ollama fails to start after this change, check the logs:
```bash
sudo journalctl -u ollama -n 30 --no-pager
```

Common issues we ran into and their fixes:

- **`permission denied` creating `/usr/share/ollama`** — the systemd-managed `ollama` user may not have access to its own data directory. Ensure ownership is correct: `sudo chown -R ollama:ollama /usr/share/ollama` (create the directory first with `sudo mkdir -p /usr/share/ollama` if it doesn't exist).
- **Models don't show up (`ollama list` is empty) after this change** — if you originally pulled models while Ollama was running as your own user (not the systemd service), your models live under `~/.ollama/models`, but the service looks in `/usr/share/ollama/.ollama/models` by default. Point it at your existing models instead of re-downloading:
  ```bash
  sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<'EOF'
  [Service]
  Environment="OLLAMA_HOST=0.0.0.0"
  Environment="OLLAMA_MODELS=/home/YOUR_USERNAME/.ollama/models"
  EOF
  sudo chmod -R o+rX /home/YOUR_USERNAME/.ollama
  chmod o+x /home/YOUR_USERNAME
  sudo systemctl daemon-reload
  sudo systemctl restart ollama
  ```
  (replace `YOUR_USERNAME` with your actual username)
- **`address already in use`** — an old Ollama process may still be running outside systemd's control. Find and stop it: `sudo lsof -i :11434`, then `sudo kill -9 <PID>`.

Verify Ollama is working correctly before proceeding:
```bash
sudo ss -tlnp | grep 11434
```
You should see it listening on `*:11434` or `0.0.0.0:11434`, not `127.0.0.1:11434`.

## Running the project

```bash
docker compose up --build
```

Then open your browser to:
```
http://localhost:8501
```

Upload a document from the sidebar, pick a model and document from the dropdowns, and ask a question.

## Bulk ingestion (optional)

To ingest many files at once from the command line instead of the UI:
```bash
python3 bulk_ingest.py ./path/to/your/folder
```
(Run this outside Docker, against a locally-running instance of the API — requires the same Python packages listed in `requirements.txt`.)

## Known limitations

This project has been extensively tested and benchmarked. Some honest, evidence-based limitations worth knowing:

- **Slow inference on CPU-only hardware.** Response times range from ~10 seconds (short factual answers) to 2-3 minutes (complex, multi-step questions), depending on your hardware and the model used.
- **Unreliable at precise counting and enumeration.** In testing, the system consistently miscounted items in lists (e.g., asked to count named components across sections of a document, answers ranged from 25 to 40 when the correct count was 29). This is a known, fundamental limitation of how transformer language models generate text — not a bug specific to this project, and not something fixable through better retrieval or prompting alone.
- **Can fabricate plausible-sounding elaboration beyond the source material**, especially when asked to "explain why" or provide reasoning not present in the retrieved context. Simple factual lookups are reliably accurate; open-ended "explain" or "rate" style questions are more prone to adding unstated, invented detail.
- **No conversation memory.** Each question is answered independently — there's no chat history or follow-up question support yet.
- **Single-provider (Ollama) only.** No support yet for hosted models like Claude or GPT.

## Roadmap / planned features

- Conversation history and follow-up question support
- Native desktop app option
- Recursive/smarter text chunking
- Web page ingestion (not just files)
- Multi-provider model support (Claude, GPT, etc.)
