# Horizontal Pod Autoscaling

API and processor Deployments scale on CPU via `autoscaling/v2` HPAs.

| Service | Staging (base) | Production (patch) |
|---------|------------------|---------------------|
| API | min 2, max 8, CPU 70% | min 3, max 12 |
| Processor | min 2, max 10, CPU 70% | min 3, max 15 |

Manifests live under `k8s/base/autoscaling/`. Production overlays patch `minReplicas` / `maxReplicas` only — do not set fixed Deployment `replicas` in overlays when HPAs are active.

## Prerequisites

HPA resource metrics require **metrics-server** on the cluster.

EKS (after `aws eks update-kubeconfig`):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# or: aws eks create-addon --cluster-name CLUSTER --addon-name metrics-server
```

Verify:

```bash
kubectl get hpa -n fiap-videos
kubectl top pods -n fiap-videos
```

## Future: queue-based scaling

CPU autoscaling helps ffmpeg workers under load. For RabbitMQ backlog, consider **KEDA** `ScaledObject` on queue length instead of (or in addition to) CPU.
