# FIAP Videos — Database

Each microservice has an **isolated PostgreSQL database** (database-per-service pattern).

## Development instances

| Mode | Postgres | Host port | Databases |
|------|----------|-----------|-----------|
| Full stack (`app-fiap-videos-infra/docker`) | Single container | `5433` | `fiap_videos_api`, `fiap_videos_processor`, `fiap_videos_notifier` |
| API only | `app-fiap-videos-api/docker-compose.yml` | `5433` | `fiap_videos_api` |
| Processor only | `app-fiap-videos-processor/docker-compose.yml` | `5434` | `fiap_videos_processor` |
| Notifier only | `app-fiap-videos-notifier/docker-compose.yml` | `5436` | `fiap_videos_notifier` |

Local credentials: user `fiap`, password `fiap`.

## Initial setup (full stack)

Script: `docker/postgres/init-dbs.sh`

- Creates all 3 databases on first Postgres startup
- Enables the `pgcrypto` extension in each database

## Migrations (Drizzle)

Each service keeps SQL migrations under:

```
src/adapter/infra/database/migrations/
```

Per-repo commands:

```bash
yarn db:migrate    # apply pending migrations
yarn db:generate   # generate migration from schema (dev)
```

Migrations run automatically on container startup (local Compose and production).

## Tables per service

### `fiap_videos_api`

| Table | Purpose |
|-------|---------|
| `users` | Accounts (admin / user), bcrypt |
| `video_jobs` | Upload jobs and status |
| `outbox` | Events to publish to RabbitMQ |
| `outbox_dead_letters` | Outbox entries after max retries |
| `processed_events` | Inbox (processor events) |

### `fiap_videos_processor`

| Table | Purpose |
|-------|---------|
| `processing_jobs` | ffmpeg worker state |
| `outbox` | Started / Completed / Failed events |
| `outbox_dead_letters` | Outbox entries after max retries |
| `processed_events` | Inbox (`VideoProcessingRequested`) |

### `fiap_videos_notifier`

| Table | Purpose |
|-------|---------|
| `processed_events` | Inbox (e-mail deduplication) |

## Redis (API only)

Caches `GET /videos` listings — 30s TTL. Not shared across services.

## Video files

Locally, API and Processor use MinIO (`STORAGE_BACKEND=minio`). In production, use AWS S3 (`STORAGE_BACKEND=s3`) — see [k8s/docs/IRSA.md](k8s/docs/IRSA.md).

## Seed (API)

```bash
cd app-fiap-videos-api
yarn db:seed
```

Demo users are documented in `app-fiap-videos-api/.env.example`.
