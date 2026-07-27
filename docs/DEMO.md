# FIAP Videos — Demo (hackathon)

Roteiro para demonstrar o fluxo completo com Docker Compose.

## 1. Subir a stack

```bash
cd app-fiap-videos-infra/docker
docker compose up --build
```

Aguarde healthchecks. URLs principais:

| Serviço | URL |
|---------|-----|
| API + login web | http://localhost:3000/login |
| Swagger | http://localhost:3000/api/docs |
| MailHog | http://localhost:8025 |
| Grafana | http://localhost:3003 (admin/admin) |
| Prometheus | http://localhost:9091 |
| Alertmanager | http://localhost:9093 |
| RabbitMQ UI | http://localhost:15673 (fiap/fiap) |

## 2. Autenticação

**Opção A — UI:** http://localhost:3000/login

**Opção B — API (admin seed ou register):**

```bash
# Login (após seed ou register)
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@fiap-videos.local","password":"demo12345"}' \
  | jq -r .accessToken)
```

Seed (API fora do Docker): `cd app-fiap-videos-api && yarn db:seed`

## 3. Upload e acompanhamento

```bash
curl -s -X POST http://localhost:3000/videos \
  -H "Authorization: Bearer $TOKEN" \
  -F 'video=@/caminho/para/video.mp4' | jq

curl -s http://localhost:3000/videos -H "Authorization: Bearer $TOKEN" | jq
```

UI de status: http://localhost:3000/status

## 4. O que mostrar ao avaliador

1. **Upload pendente** → e-mail no MailHog (`VideoProcessingRequested`).
2. **Processor** extrai frames (logs do container `processor`).
3. **Status `completed`** na API (evento `VideoProcessingCompleted`).
4. **E-mail de sucesso** no MailHog.
5. **Download** do zip:

```bash
curl -L -o frames.zip "http://localhost:3000/videos/JOB_ID/download" \
  -H "Authorization: Bearer $TOKEN"
```

6. **Grafana** — dashboard *FIAP Videos — Overview*.
7. **Prometheus / Alertmanager** — targets UP; regras carregadas.

## 5. Coleção Insomnia

Importar `insomnia/fiap-videos-local.json` para requests prontos (auth admin, upload, status).

## 6. Escalabilidade (opcional)

```bash
docker compose up --build --scale processor=3
```

Ver filas no RabbitMQ UI e métricas no Grafana.

## Evidências para entrega

- Screenshot MailHog com 2+ e-mails (requested + completed)
- Screenshot Grafana com jobs processados
- Screenshot GitHub Actions (CI verde nos 3 app repos + infra)
- `kubectl get pods` / HPA (quando staging EKS estiver provisionado)
