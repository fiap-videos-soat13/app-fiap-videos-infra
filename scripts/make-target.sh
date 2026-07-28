#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") <target>

Targets:
  platform-up       terraform apply + cluster addons (ingress, ESO, metrics-server)
  platform-down     terraform destroy
  bootstrap-addons  install/upgrade cluster addons only (after terraform)
  deploy-staging    deploy RabbitMQ/Redis + staging overlay to EKS
  render-staging    print rendered staging manifests to stdout

Examples:
  make platform-up
  make deploy-staging
EOF
}

target="${1:-}"
if [[ -z "${target}" ]]; then
  usage
  exit 1
fi

cd "${INFRA_DIR}"

case "${target}" in
  platform-up)
    terraform -chdir=terraform init -backend-config=backend.staging.hcl
    terraform -chdir=terraform apply
    "${SCRIPT_DIR}/bootstrap-cluster-addons.sh"
    ;;
  platform-down)
    terraform -chdir=terraform destroy
    ;;
  bootstrap-addons)
    "${SCRIPT_DIR}/bootstrap-cluster-addons.sh"
    ;;
  deploy-staging)
    "${SCRIPT_DIR}/deploy-staging.sh"
    ;;
  render-staging)
    # shellcheck source=export-deploy-env.sh
    source "${SCRIPT_DIR}/export-deploy-env.sh" "${2:---dummy}"
    kubectl kustomize k8s/overlays/staging | envsubst "${ENVSUBST_VARS}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
