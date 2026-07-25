# FIAP Videos — Infraestrutura local

Stack completa via Docker Compose:

```bash
cd docker
docker compose up --build
```

## Serviços

| Serviço | Porta | Descrição |
|---------|-------|-----------|
| API | 3000 | Upload, auth, status, download |
| Processor | 3001 | Workers ffmpeg + zip |
| Notifier | 3002 | E-mail em falhas |
| PostgreSQL | 5432 | Persistência (3 databases) |
| Redis | 6380 | Cache de listagem |
| **RabbitMQ** | **5673 / 15673** | **Único broker compartilhado** (fiap / fiap) |
| MailHog | 8025 | E-mails de teste |
| Prometheus | 9091 | Métricas |
| Grafana | 3003 | Dashboards |

## RabbitMQ compartilhado

Há **um único RabbitMQ** para todo o projeto (`fiap-videos-rabbitmq`, porta `5673`).

Ao desenvolver com `yarn start:dev` ou com docker-compose de um serviço isolado, suba só o broker:

```bash
cd docker
docker compose up rabbitmq -d
```

Todos os serviços usam:

```env
RABBITMQ_URL=amqp://fiap:fiap@localhost:5673/
```

UI: http://localhost:15673

## Dependências apenas (dev server)

```bash
cd docker
docker compose up postgres redis rabbitmq mailhog -d
```

Depois rode cada serviço com `yarn start:dev` nos respectivos repositórios.

## Kubernetes

Manifests básicos em `k8s/` (HPA no processor para escalar workers).
