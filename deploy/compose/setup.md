# TDAI Memory Stack — Docker Compose Deployment

## Quick Start

```bash
cd deploy/compose

# 1. Create .env from template
cp .env.example .env

# 2. Edit .env — set your LLM provider credentials
#    MEMORY_LLM_*   — used by memory-core (embeddings, summarization)
#    PROXY_UPSTREAM_* — used by proxy (forwarded to coding agents)
# 
#    Example (Hetzner Inference API):
#    MEMORY_LLM_BASE_URL=https://inference.hetzner.com/api/v1
#    MEMORY_LLM_API_KEY=c2q_...
#    MEMORY_LLM_MODEL=Qwen3.8-27B
#    PROXY_UPSTREAM_URL=https://inference.hetzner.com/api/v1
#    PROXY_UPSTREAM_API_KEY=c2q_...
#    PROXY_UPSTREAM_MODEL=Qwen3.8-27B

# 3. Start the stack
docker compose up -d

# 4. Wait for healthchecks (~15s), then verify
curl http://localhost:8420/health       # memory-core gateway
curl http://localhost:8096/health       # proxy
curl http://localhost:8424/health       # memory-hub knowledge
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| `memory-core` | 8420 | Memory gateway — auth, L0/L1/L2/L3 memory, skill extraction |
| `memory-hub` | 8125 | Web panel UI |
| `memory-hub` | 8424 | Knowledge base service |
| `proxy` | 8096 | Context proxy — forwards to upstream LLM with memory injection |
| `config` | — | One-shot init: renders gateway + proxy YAML configs |
| `init-admin` | — | One-shot init: creates admin user (idempotent) |

## Making Requests

All requests to the proxy require the `default` space ID in the path and a Bearer token:

```bash
curl -X POST http://localhost:8096/proxy/default/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-mem-change-me-please-0123456789" \
  -d '{
    "model": "Qwen3.8-27B",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello"}
    ],
    "max_tokens": 256
  }'
```

The admin user key (`MEMORY_CORE_ADMIN_USER_KEY`) doubles as the client credential — pass it as `Authorization: Bearer <key>`.

## Common Operations

```bash
docker compose logs -f               # tail all logs
docker compose logs -f proxy         # tail specific service
docker compose down                  # stop containers (data persists in volumes)
docker compose down -v               # stop + destroy volumes (clean slate)
docker compose up -d --force-recreate # rebuild after .env changes
```

## Volumes

- `tdai-memory-core-data` — gateway database and config
- `tdai-panel-data` — hub UI state
- `tdai-proxy-data` — proxy session state (SQLite when Redis is disabled)
- `tdai-config` — shared volume holding rendered `tdai-gateway.yaml` and `proxy-config.yaml` (read-only, managed by `config` service)
