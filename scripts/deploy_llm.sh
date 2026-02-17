#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <vllm-irsa-role-arn> <acm-certificate-arn> <api-hostname>"
  exit 1
fi

VLLM_IRSA_ROLE_ARN="$1"
ACM_CERT_ARN="$2"
API_HOSTNAME="$3"

kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/storageclass-gp3.yaml

kubectl apply -f k8s/apps/vllm/secret-hf-token.example.yaml
kubectl apply -f k8s/apps/gateway/secret-api-key.example.yaml

sed "s|REPLACE_VLLM_IRSA_ROLE_ARN|${VLLM_IRSA_ROLE_ARN}|g" k8s/apps/vllm/serviceaccount.yaml | kubectl apply -f -

kubectl apply -f k8s/apps/vllm/pvc.yaml
kubectl apply -f k8s/apps/vllm/deployment.yaml
kubectl apply -f k8s/apps/vllm/service.yaml
kubectl apply -f k8s/apps/vllm/pdb.yaml

kubectl apply -f k8s/apps/gateway/nginx-conf-template.yaml
kubectl apply -f k8s/apps/gateway/deployment.yaml
kubectl apply -f k8s/apps/gateway/service.yaml

sed \
  -e "s|REPLACE_ACM_CERTIFICATE_ARN|${ACM_CERT_ARN}|g" \
  -e "s|llm.api.yourdomain.com|${API_HOSTNAME}|g" \
  k8s/apps/gateway/ingress.yaml | kubectl apply -f -

kubectl apply -f k8s/autoscaling/hpa-gateway.yaml
kubectl apply -f k8s/autoscaling/hpa-vllm.yaml
kubectl apply -f k8s/autoscaling/scaledobject-vllm-queue.yaml

kubectl apply -f k8s/security/networkpolicy-default-deny.yaml
kubectl apply -f k8s/security/networkpolicy-allow-gateway.yaml
kubectl apply -f k8s/security/networkpolicy-allow-vllm-egress.yaml

kubectl apply -f k8s/observability/servicemonitor-vllm.yaml
kubectl apply -f k8s/observability/prometheusrule-llm.yaml

echo "LLM stack deployed."
