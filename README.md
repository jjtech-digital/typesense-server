# Typesense Server (Dockerized)

A containerized [Typesense](https://typesense.org/) search engine deployment with a [Caddy](https://caddyserver.com/) reverse proxy, designed for one-click deployment on [Railway](https://railway.app/).

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/jjtech-digital/typesense-server)

## Architecture

```
Internet → Railway ($PORT) → Caddy (reverse proxy) → Typesense (127.0.0.1:8118)
```

- **Caddy** listens on the Railway-assigned `$PORT` and forwards traffic to Typesense.
- **Typesense** binds to `127.0.0.1:8118`, accessible only through the reverse proxy.
- Both processes run in the background and are managed by a single entry point script with graceful signal handling.

## Project Structure

```
├── Caddyfile                 # Caddy reverse proxy configuration
├── .dockerignore             # Files excluded from Docker build context
├── Dockerfile                # Multi-stage Docker build
├── railway.json              # Railway infrastructure config (config-as-code)
├── railway.template.json     # Railway template for one-click deploy
├── railway-variables.json    # Environment variables for quick setup via CLI
└── scripts/
    ├── start.sh              # Entry point — runs Caddy & Typesense with signal handling
    ├── start_caddy.sh        # Starts Caddy with the Caddyfile
    ├── start_typesense.sh    # Starts the Typesense server
    ├── backup.sh             # On-demand backup/snapshot management
    └── scheduled_backup.sh   # Automated periodic backup scheduler
```

## Tech Stack

| Component       | Version / Details                        |
| --------------- | ---------------------------------------- |
| Typesense       | 30.1                                     |
| Caddy           | Latest (installed in Dockerfile)         |
| Base OS         | Debian-based (Typesense official image)  |
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
| `BACKUP_ENABLED` | `true` | Enable automated periodic backups (`true`/`false`) |
| `BACKUP_INTERVAL_HOURS` | `6` | Hours between automated backups |
| `BACKUP_RETENTION_DAYS` | `7` | Days to retain old backups |
| `BACKUP_MAX_COUNT` | `10` | Maximum number of backup snapshots to keep |

> **Note:** `RAILWAY_VOLUME_MOUNT_PATH`, `RAILWAY_PUBLIC_DOMAIN`, and `RAILWAY_PRIVATE_DOMAIN` are automatically provided by Railway. Use Railway's variable reference syntax `${{VAR}}` to reference them.

All variables are pre-defined in `railway-variables.json` for quick setup. You can bulk-import them using the Railway CLI:

```bash
# Link to your Railway project first
railway link

# Set all variables at once
cat railway-variables.json | jq -r 'to_entries[] | "\(.key)=\(.value)"' | while read var; do
  railway variables set "$var"
done
```

> **Important:** Replace `CHANGE_ME_GENERATE_A_SECURE_KEY` in `railway-variables.json` with a secure API key before importing.

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
docker run -e PORT=8080 -e TYPESENSE_API_KEY="$(openssl rand -hex 32)" -p 8080:8080 typesense-server
```

Once running, the Typesense API is available at `http://localhost:8080`.

## Security

- **Non-root container** — The container runs as a dedicated `typesense` user, not `root`.
- **Loopback-only Typesense** — The Typesense API binds to `127.0.0.1`, inaccessible from outside the container. All external traffic goes through Caddy.
- **Admin API disabled** — Caddy's admin API is turned off to prevent unauthorized configuration changes.
- **API key validation** — The entry point script validates that a strong API key is set before starting services. Placeholder values and keys shorter than 32 characters are rejected or warned.
- **Security headers** — Caddy injects protective HTTP headers: `X-Content-Type-Options`, `X-Frame-Options`, `X-XSS-Protection`, `Referrer-Policy`, and `Permissions-Policy`. The `Server` header is stripped.
- **Request body limits** — Caddy enforces a 100MB max request body size to prevent abuse.
- **Graceful shutdown** — Signal handlers (TERM, INT, QUIT) ensure clean process termination and a pre-shutdown snapshot when possible.
- **Docker build hardening** — `.dockerignore` excludes secrets, docs, and IDE files from the build context. `gosu` is verified after installation.
- **Container health checks** — Docker `HEALTHCHECK` instruction monitors Typesense availability.

## Data Protection & Backups

The backup system uses Typesense's built-in `/operations/snapshot` API for consistent, point-in-time backups.

### Automated Backups

Enabled by default when using the Railway template. Set `BACKUP_ENABLED=true` to activate.

- Snapshots are taken every `BACKUP_INTERVAL_HOURS` (default: 6 hours)
- Old backups are cleaned up after `BACKUP_RETENTION_DAYS` (default: 7 days)
- Maximum `BACKUP_MAX_COUNT` snapshots are retained (default: 10)
- A pre-shutdown snapshot is attempted on graceful container stop

### Manual Backup Commands

Run inside the container:

```bash
# Create a manual snapshot
/bin/sh backup.sh

# Create a labeled snapshot
/bin/sh backup.sh my-label

# List all existing backups
/bin/sh backup.sh --list

# Remove backups older than 3 days
/bin/sh backup.sh --cleanup 3
```

### Backup Storage

Backups are stored in `/data/backups/` on the persistent Railway volume. Each snapshot is a directory named `{label}_{timestamp}`.

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
