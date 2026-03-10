# Typesense Server (Dockerized)

A containerized [Typesense](https://typesense.org/) search engine deployment with a [Caddy](https://caddyserver.com/) reverse proxy, designed for one-click deployment on [Railway](https://railway.app/).

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/jjtech-digital/typesense-server)

## Architecture

```
Internet → Railway ($PORT) → Caddy (reverse proxy) → Typesense (127.0.0.1:8118)
```

- **Caddy** listens on the Railway-assigned `$PORT` and forwards traffic to Typesense.
- **Typesense** binds to `127.0.0.1:8118`, accessible only through the reverse proxy.
- Both processes run in parallel using GNU `parallel` and are managed by a single entry point script.

## Project Structure

```
├── Caddyfile                 # Caddy reverse proxy configuration
├── Dockerfile                # Multi-stage Docker build
├── railway.json              # Railway infrastructure config (config-as-code)
├── railway.template.json     # Railway template for one-click deploy
└── scripts/
    ├── start.sh              # Entry point — runs Caddy & Typesense in parallel
    ├── start_caddy.sh        # Starts Caddy with the Caddyfile
    └── start_typesense.sh    # Starts the Typesense server
```

## Tech Stack

| Component       | Version / Details                        |
| --------------- | ---------------------------------------- |
| Typesense       | 30.1                                     |
| Caddy           | Latest (installed in Dockerfile)         |
| Base OS         | Alpine Linux (for GNU parallel)          |
| Containerization| Docker (multi-stage build)               |

## Environment Variables

Set the following environment variables in your Railway service settings:

| Variable | Example Value | Description |
| -------- | ------------- | ----------- |
| `PORT` | `8080` | Public-facing port (auto-assigned by Railway) |
| `TYPESENSE_API_KEY` | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` | API key for authenticating requests to Typesense |
| `TYPESENSE_DATA_DIR` | `${{RAILWAY_VOLUME_MOUNT_PATH}}` | Directory for persistent data storage (use Railway volume mount) |
| `TYPESENSE_NUM_COLLECTIONS_PARALLEL_LOAD` | `32` | Number of collections to load in parallel at startup |
| `TYPESENSE_PUBLIC_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL for the Typesense instance |
| `TYPESENSE_THREAD_POOL_SIZE` | `64` | Number of threads in the Typesense thread pool |
| `TYPESENSE_URL` | `http://${{RAILWAY_PRIVATE_DOMAIN}}:${{PORT}}` | Internal URL for service-to-service communication |

> **Note:** `RAILWAY_VOLUME_MOUNT_PATH`, `RAILWAY_PUBLIC_DOMAIN`, and `RAILWAY_PRIVATE_DOMAIN` are automatically provided by Railway. Use Railway's variable reference syntax `${{VAR}}` to reference them.

## Railway Config-as-Code

Infrastructure-level settings are managed via [`railway.json`](https://docs.railway.com/config-as-code) for version-controlled, reproducible deployments.

```json
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile",
    "watchPatterns": ["Dockerfile", "Caddyfile", "scripts/*"]
  },
  "deploy": {
    "healthcheckPath": "/health",
    "healthcheckTimeout": 120,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 5,
    "drainingSeconds": 30
  }
}
```

| Setting | Value | Description |
| ------- | ----- | ----------- |
| `builder` | `DOCKERFILE` | Uses the project's Dockerfile for builds |
| `dockerfilePath` | `Dockerfile` | Path to the Dockerfile |
| `watchPatterns` | `Dockerfile`, `Caddyfile`, `scripts/*` | Only trigger redeployments when these files change |
| `healthcheckPath` | `/health` | Railway pings this endpoint to verify the service is healthy |
| `healthcheckTimeout` | `120` | Seconds to wait for a healthy response before marking as failed |
| `restartPolicyType` | `ON_FAILURE` | Automatically restart the container if it crashes |
| `restartPolicyMaxRetries` | `5` | Maximum restart attempts before giving up |
| `drainingSeconds` | `30` | Graceful shutdown period — time between SIGTERM and SIGKILL during redeployments |

### Scaling (via Railway Dashboard)

Scaling options are configured through the Railway dashboard, not via `railway.json`:

- **Vertical scaling** — Railway automatically scales vCPU and memory up to your plan limits.
- **Horizontal scaling** — Increase replicas in **Service Settings > Deploy > Regions**. Each replica gets full plan resources. Railway automatically load-balances traffic across replicas and routes to the nearest region.
- **Multi-region** — Assign replicas to different regions from the same settings panel for geo-distributed deployments.

> Each replica exposes `RAILWAY_REPLICA_ID` and `RAILWAY_REPLICA_REGION` environment variables for observability.

### Volumes (via Railway Dashboard)

Volumes are managed through the Railway dashboard and cannot be configured via `railway.json`:

1. Go to your service in the Railway dashboard.
2. Click **Settings > Volumes > Add Volume**.
3. Set the mount path to match `TYPESENSE_DATA_DIR` (e.g., `/data`).

> Volumes persist data across redeployments and restarts. If you're running out of space, you can resize volumes from the dashboard without downtime.

## Deployment on Railway

### One-Click Deploy (Recommended)

Click the button below to deploy with pre-configured environment variables and a volume attached automatically:

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/jjtech-digital/typesense-server)

The template (`railway.template.json`) pre-configures:
- All environment variables with sensible defaults
- Auto-generated `TYPESENSE_API_KEY`
- A persistent volume mounted at `/data`
- Health checks and restart policies

### Manual Setup

1. Fork or clone this repository.
2. Create a new project on [Railway](https://railway.app/).
3. Connect the repository to Railway.
4. Add a **volume** to the service (required for `TYPESENSE_DATA_DIR` persistence).
5. Configure the environment variables listed above in the service settings.
6. Railway will automatically detect the `Dockerfile`, build the image, and deploy it.

## Running Locally with Docker

```bash
# Build the image
docker build -t typesense-server .

# Run the container (expose on port 8080)
docker run -e PORT=8080 -p 8080:8080 typesense-server
```

Once running, the Typesense API is available at `http://localhost:8080`.

## Security

- **Non-root container** — The container runs as a dedicated `typesense` user, not `root`.
- **`cap_net_bind_service`** — Caddy is granted only the minimum capability needed to bind to low-numbered ports.
- **Loopback-only Typesense** — The Typesense API binds to `127.0.0.1`, inaccessible from outside the container. All external traffic goes through Caddy.
- **Admin API disabled** — Caddy's admin API is turned off to prevent unauthorized configuration changes.

## Key Configuration

- **CORS** is enabled on the Typesense server.
- **HTTPS** is disabled in Caddy (Railway handles TLS termination).
- Caddy runtime logs are discarded to keep output clean.

## API Usage

Refer to the [Typesense API documentation](https://typesense.org/docs/30.0/api/) for available endpoints. Example:

```bash
# Health check
curl http://localhost:8080/health
```

## License

This project is provided as-is. Typesense is licensed under the [GNU GPL v3](https://github.com/typesense/typesense/blob/master/LICENSE.txt).
