# FIAP Videos — Banco de dados

Cada microsserviço possui **database PostgreSQL isolado** (padrão database-per-service).

## Instâncias em desenvolvimento

| Modo | Postgres | Porta host | Databases |
|------|----------|------------|-----------|
| Stack completa (`app-fiap-videos-infra/docker`) | Container único | `5433` | `fiap_videos_api`, `fiap_videos_processor`, `fiap_videos_notifier` |
| API isolada | `app-fiap-videos-api/docker-compose.yml` | `5433` | `fiap_videos_api` |
| Processor isolado | `app-fiap-videos-processor/docker-compose.yml` | `5434` | `fiap_videos_processor` |
| Notifier isolado | `app-fiap-videos-notifier/docker-compose.yml` | `5436` | `fiap_videos_notifier` |

Credenciais locais: usuário `fiap`, senha `fiap`.

## Criação inicial (stack completa)

Script: `docker/postgres/init-dbs.sh`

- Cria os 3 databases na primeira subida do Postgres
- Habilita extensão `pgcrypto` em cada database

## Migrations (Drizzle)

Cada serviço mantém migrations SQL em:

```
src/adapter/infra/database/migrations/
```

Comandos por repo:

```bash
yarn db:migrate    # aplica migrations pendentes
yarn db:generate   # gera migration a partir do schema (dev)
```

Migrations rodam automaticamente no startup dos containers de produção/local compose.

## Tabelas por serviço

### `fiap_videos_api`

| Tabela | Uso |
|--------|-----|
| `users` | Contas (admin / user), bcrypt |
| `video_jobs` | Jobs de upload e status |
| `outbox` | Eventos a publicar no RabbitMQ |
| `outbox_dead_letters` | Outbox após max tentativas |
| `processed_events` | Inbox (eventos do processor) |

### `fiap_videos_processor`

| Tabela | Uso |
|--------|-----|
| `processing_jobs` | Estado do worker ffmpeg |
| `outbox` | Eventos Started / Completed / Failed |
| `outbox_dead_letters` | Outbox após max tentativas |
| `processed_events` | Inbox (VideoProcessingRequested) |

### `fiap_videos_notifier`

| Tabela | Uso |
|--------|-----|
| `processed_events` | Inbox (deduplicação de e-mails) |

## Redis (somente API)

Cache de listagem `GET /videos` — TTL 30s. Não compartilhado entre serviços.

## Arquivos de vídeo

Em dev local, API e Processor compartilham volume `video_storage` (filesystem).  
Em produção, migrar para S3 (`STORAGE_BACKEND=s3`) — ver roadmap infra-k8s.

## Seed (API)

```bash
cd app-fiap-videos-api
yarn db:seed
```

Usuários demo documentados em `app-fiap-videos-api/.env.example`.
