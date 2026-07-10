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
| PostgreSQL | 5433 | Persistência |
| Redis | 6380 | Cache de listagem |
| RabbitMQ | 5673 / 15673 | Mensageria + UI |
| MailHog | 8025 | E-mails de teste |
| Prometheus | 9091 | Métricas |
| Grafana | 3003 | Dashboards |

## Kubernetes

Manifests básicos em `k8s/` (HPA no processor para escalar workers).
