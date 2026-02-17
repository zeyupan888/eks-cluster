# EKS + vLLM Runbook

## Prerequisites
- AWS CLI authenticated for target account.
- `terraform >=1.6`, `kubectl`, `helm`, `jq`, `sed`.
- ECR pull rights for container images.
- Hugging Face token for gated Llama model access.

## 1) Define requirements first
- Fill `docs/requirements.md` before deployment.
- Confirm model, QPS, latency SLO, and monthly budget.

## 2) Provision AWS foundation + EKS
```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform apply
```

## 3) Configure kubectl
```bash
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
```

## 4) Install add-ons
```bash
LB_ROLE_ARN=$(terraform output -raw lb_controller_irsa_role_arn)
../../scripts/install_addons.sh "$CLUSTER_NAME" "$REGION" "$LB_ROLE_ARN"
```

## 5) Deploy vLLM + gateway + ingress
```bash
VLLM_ROLE_ARN=$(terraform output -raw vllm_irsa_role_arn)
ACM_CERT_ARN=$(grep '^acm_certificate_arn' terraform.tfvars | cut -d '"' -f2)
API_HOSTNAME=$(grep '^api_hostname' terraform.tfvars | cut -d '"' -f2)

cd ../..
./scripts/deploy_llm.sh "$VLLM_ROLE_ARN" "$ACM_CERT_ARN" "$API_HOSTNAME"
```

## 6) Point DNS
- Get ALB hostname:
```bash
kubectl -n llm get ingress llm-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
- Create/Update Route53 CNAME from `api_hostname` to the ALB hostname.

## 7) Smoke test
```bash
./scripts/smoke_test.sh llm.api.yourdomain.com replace-with-long-random-key
```

## 8) Scale and reliability
- HPA manifests are under `k8s/autoscaling/`.
- KEDA `ScaledObject` is included; tune Prometheus query/threshold.
- Add Cluster Autoscaler or Karpenter for GPU node autoscaling.

## 9) Observability
- Prometheus + Grafana installed with `scripts/install_addons.sh`.
- Alerts in `k8s/observability/prometheusrule-llm.yaml`.
- Send logs to CloudWatch using Fluent Bit/ADOT in a follow-up step.

## 10) Security hardening checklist
- Keep EKS endpoint private or CIDR-restricted.
- Rotate API key and HF token in Kubernetes Secrets.
- Enforce signed images and scan with ECR/Trivy.
- Keep network policies enabled in `k8s/security/`.
