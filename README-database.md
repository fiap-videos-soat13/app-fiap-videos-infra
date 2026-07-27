# FIAP Videos — Database

Each microservice has an **isolated PostgreSQL database** (database-per-service pattern). Services never share tables — only domain events over RabbitMQ link them.

## Development instances

| Mode | Compose file | Host port | Databases |
|------|--------------|-----------|-----------|
| Full stack | `app-fiap-videos-infra/docker/docker-compose.yml` | `5432` | `fiap_videos_api`, `fiap_videos_processor`, `fiap_videos_notifier` |
| API only | `app-fiap-videos-api/docker-compose.yml` | `5432` | `fiap_videos_api` |
| Processor only | `app-fiap-videos-processor/docker-compose.yml` | `5432` | `fiap_videos_processor` |
| Notifier only | `app-fiap-videos-notifier/docker-compose.yml` | `5432` | `fiap_videos_notifier` |

Local credentials: user `fiap`, password `fiap`.

> **Port conflicts** — every Compose file maps Postgres to host port `5432`. Run only one Postgres mapping at a time, or remap the host port in the compose file you need.

Example `DATABASE_URL` values when connecting from the host:

```bash
# Full stack (infra docker)
postgresql://fiap:fiap@localhost:5432/fiap_videos_api
postgresql://fiap:fiap@localhost:5432/fiap_videos_processor
postgresql://fiap:fiap@localhost:5432/fiap_videos_notifier
```

Inside the full-stack Compose network, services use the internal hostname `postgres:5432`.

## Initial setup (full stack)

Script: `docker/postgres/init-dbs.sh` (mounted as `docker-entrypoint-initdb.d` on first Postgres startup)

- Creates `fiap_videos_api`, `fiap_videos_processor`, and `fiap_videos_notifier` if they do not exist
- Enables the `pgcrypto` extension in each database

Isolated service composes use per-repo `docker/init-db.sql` to create a single database on first boot.

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

| Environment | How migrations run |
|-------------|----------------------|
| Local Compose | Automatically on app container startup |
| Kubernetes | One-shot Jobs per service (`fiap-videos-*-db-migration`) before rollouts |
| `yarn start:dev` | Run `yarn db:migrate` manually once, or rely on startup migration |

Migration Jobs live in `k8s/base/migration-jobs/` and use the `*-migrator` ECR image (`node scripts/docker-migrate.js`). Staging deploy waits for all three Jobs to complete (`make deploy-staging`).

## Tables per service

### `fiap_videos_api`

| Table | Purpose |
|-------|---------|
| `users` | Accounts (`admin` / `user`), bcrypt passwords |
| `video_jobs` | Upload jobs, status, storage keys, correlation IDs |
| `outbox` | Events to publish to RabbitMQ |
| `outbox_dead_letters` | Outbox entries after max retries |
| `processed_events` | Inbox (processor lifecycle events) |

### `fiap_videos_processor`

| Table | Purpose |
|-------|---------|
| `processing_jobs` | Local worker state (idempotent re-processing) |
| `outbox` | `Started` / `Completed` / `Failed` events |
| `outbox_dead_letters` | Outbox entries after max retries |
| `processed_events` | Inbox (`VideoProcessingRequested`) |

### `fiap_videos_notifier`

| Table | Purpose |
|-------|---------|
| `processed_events` | Inbox (e-mail deduplication) |

## Redis (API only)

Caches `GET /videos` listings — **30s TTL**. Not shared across services. Local host port: `6380` (full stack).

## Object storage (not in PostgreSQL)

Video and zip files are **not** stored in the database:

| Path prefix | Writer | Reader |
|-------------|--------|--------|
| `videos/{jobId}-{file}` | API | Processor |
| `zips/{jobId}.zip` | Processor | API |

| Environment | Backend |
|-------------|---------|
| Local | MinIO (`STORAGE_BACKEND=minio`, port `9000`) |
| Staging / production | AWS S3 (`STORAGE_BACKEND=s3`) — see [k8s/docs/IRSA.md](k8s/docs/IRSA.md) |

## Production (AWS RDS)

Terraform provisions a single RDS instance. RDS starts with only the default database `fiap_videos`; create per-service databases once:

```bash
cd terraform
terraform output -raw rds_init_sql
```

Or run the commands from [terraform/README.md](terraform/README.md#one-time-rds-setup).

Connection strings are stored in AWS Secrets Manager and synced to Kubernetes:

| Secret Manager key | K8s `DATABASE_URL` for |
|--------------------|------------------------|
| `fiap-videos/{env}/api-database-url` | API + API migration Job |
| `fiap-videos/{env}/processor-database-url` | Processor + processor migration Job |
| `fiap-videos/{env}/notifier-database-url` | Notifier + notifier migration Job |

See [k8s/docs/EXTERNAL-SECRETS.md](k8s/docs/EXTERNAL-SECRETS.md).

## Seed (API)

```bash
cd app-fiap-videos-api
yarn db:seed
```

Demo users are documented in `app-fiap-videos-api/.env.example`. Alternatively, set `BOOTSTRAP_USERS=true` on API startup.

## Integration tests (ephemeral Postgres)

`scripts/run-integration-tests.sh` in each app repo starts a throwaway Postgres container on a **dedicated host port** so tests do not conflict with dev Compose:

| Service | Test script host port | Default test database |
|---------|----------------------|------------------------|
| API | `5432` | `fiap_videos_api_test` |
| Processor | `5433` | `fiap_videos_processor_test` |
| Notifier | `5434` | `fiap_videos_notifier_test` |

Dev and full-stack Compose still use host port `5432` for Postgres.

## Related docs

- [README.md](README.md) — platform overview
- [terraform/README.md](terraform/README.md) — RDS provisioning
- [README-CICD.md](README-CICD.md) — deploy flow (includes migration Jobs)
- [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) — database ownership in system design
