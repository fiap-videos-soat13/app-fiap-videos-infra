#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${INFRA_DIR}/terraform"

export ENVSUBST_VARS='${AWS_ACCOUNT_ID} ${AWS_REGION} ${S3_BUCKET} ${API_IRSA_ARN} ${PROCESSOR_IRSA_ARN} ${ESO_IRSA_ARN} ${EKS_CLUSTER_NAME}'

export_env_dummy() {
  export AWS_ACCOUNT_ID="123456789012"
  export AWS_REGION="us-east-2"
  export S3_BUCKET="fiap-videos-staging-videos"
  export API_IRSA_ARN="arn:aws:iam::123456789012:role/fiap-videos-staging-api-s3"
  export PROCESSOR_IRSA_ARN="arn:aws:iam::123456789012:role/fiap-videos-staging-processor-s3"
  export ESO_IRSA_ARN="arn:aws:iam::123456789012:role/fiap-videos-staging-external-secrets"
  export EKS_CLUSTER_NAME="fiap-videos-staging"
}

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

export_env_from_ci() {
  require aws
  export AWS_REGION="${AWS_REGION:-us-east-2}"
  export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
  export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-fiap-videos-staging}"
  : "${S3_BUCKET:?Set S3_BUCKET (GitHub variable or env)}"
  : "${API_IRSA_ARN:?Set API_IRSA_ARN}"
  : "${PROCESSOR_IRSA_ARN:?Set PROCESSOR_IRSA_ARN}"
  : "${ESO_IRSA_ARN:?Set ESO_IRSA_ARN}"
}

export_env_from_terraform() {
  require terraform
  require jq

  export AWS_ACCOUNT_ID
  AWS_ACCOUNT_ID="$(terraform -chdir="${TF_DIR}" output -raw aws_account_id)"
  export AWS_REGION
  AWS_REGION="$(terraform -chdir="${TF_DIR}" output -raw aws_region)"
  export S3_BUCKET
  S3_BUCKET="$(terraform -chdir="${TF_DIR}" output -raw video_bucket_name)"
  export API_IRSA_ARN
  API_IRSA_ARN="$(terraform -chdir="${TF_DIR}" output -json irsa_s3_role_arns | jq -r .api)"
  export PROCESSOR_IRSA_ARN
  PROCESSOR_IRSA_ARN="$(terraform -chdir="${TF_DIR}" output -json irsa_s3_role_arns | jq -r .processor)"
  export ESO_IRSA_ARN
  ESO_IRSA_ARN="$(terraform -chdir="${TF_DIR}" output -raw eso_irsa_role_arn)"
  export EKS_CLUSTER_NAME
  EKS_CLUSTER_NAME="$(terraform -chdir="${TF_DIR}" output -raw eks_cluster_name)"
}

ci_vars_present() {
  [[ -n "${S3_BUCKET:-}" && -n "${API_IRSA_ARN:-}" && -n "${PROCESSOR_IRSA_ARN:-}" && -n "${ESO_IRSA_ARN:-}" ]]
}

if [[ "${1:-}" == "--dummy" ]]; then
  export_env_dummy
elif [[ -n "${USE_DUMMY_DEPLOY_ENV:-}" ]]; then
  export_env_dummy
elif ci_vars_present; then
  export_env_from_ci
else
  export_env_from_terraform
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
  echo "AWS_REGION=${AWS_REGION}"
  echo "S3_BUCKET=${S3_BUCKET}"
  echo "EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME}"
fi
