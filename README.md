# EKS Llama Inference Platform

High-level baseline for running `meta-llama/Llama-3.1-8B-Instruct` on Amazon EKS using vLLM, exposed through an OpenAI-compatible API.

## What this project provides

- AWS foundation for an inference platform:
  - VPC across multiple AZs.
  - EKS cluster with separate CPU and GPU node groups.
  - IAM/IRSA patterns for secure pod access.
- LLM serving on Kubernetes:
  - vLLM deployment pinned to GPU nodes.
  - Persistent model cache volume.
- Public API endpoint:
  - HTTPS ingress through AWS Load Balancer Controller.
  - OpenAI-style endpoint: `/v1/chat/completions`.
  - Simple API key auth gateway.
- Production foundations:
  - Autoscaling templates (HPA/KEDA).
  - Observability hooks (Prometheus/Grafana + alerts).
  - Security baseline (network policies, KMS secret encryption).

## How the system works

1. Infrastructure layer
- Terraform provisions networking and EKS.
- CPU nodes run system/gateway workloads; GPU nodes run inference pods.
- IRSA maps Kubernetes service accounts to least-privilege IAM roles.

2. Inference layer
- vLLM runs in Kubernetes and serves `Llama-3.1-8B-Instruct`.
- Model artifacts are pulled from Hugging Face (or optional S3) and cached on EBS.

3. API layer
- NGINX gateway receives API requests and validates `Authorization: Bearer <API_KEY>`.
- Authorized requests are proxied to vLLM using OpenAI-compatible paths.

4. Edge and TLS layer
- ALB is created from Kubernetes Ingress.
- ACM certificate handles HTTPS termination.
- Route53 points your API hostname to the ALB.

5. Reliability and operations
- HPA/KEDA scale pods based on load/metrics.
- Prometheus/Grafana collect metrics and drive alerts.
- Network policies and KMS-backed secrets encryption provide baseline security.

End-to-end flow:
Client -> ALB (HTTPS) -> NGINX auth gateway -> vLLM on GPU -> response.

## Architecture (high level)

Client -> ALB Ingress (HTTPS) -> API Gateway Pod (auth) -> vLLM Pod (GPU) -> model source/cache.

## Repository structure

- `/Users/Interstellar/eks-cluster/infra/terraform`: AWS + EKS provisioning.
- `/Users/Interstellar/eks-cluster/k8s`: Kubernetes manifests for apps, autoscaling, security, observability.
- `/Users/Interstellar/eks-cluster/scripts`: helper scripts for add-ons, deployment, and smoke testing.
- `/Users/Interstellar/eks-cluster/docs`: requirements template and runbook.

## Deployment flow

1. Define requirements (model size, QPS, latency, budget).
2. Apply Terraform to create AWS/EKS foundation.
3. Install cluster add-ons (LB controller, NVIDIA plugin, metrics/monitoring).
4. Deploy vLLM + gateway + ingress manifests.
5. Point DNS to ALB and run smoke test.

Detailed steps are in `/Users/Interstellar/eks-cluster/docs/runbook.md`.

## API validation example

```bash
curl https://llm.api.yourdomain.com/v1/chat/completions \
  -H "Authorization: Bearer <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"model":"meta-llama/Llama-3.1-8B-Instruct","messages":[{"role":"user","content":"Hello"}]}'
```

## Notes

- Start with `Llama-3.1-8B-Instruct`; move to larger models only after benchmarking.
- Replace placeholder secrets/ARNs/domains before production use.
