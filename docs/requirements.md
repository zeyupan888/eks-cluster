# LLM Platform Requirements (Fill Before Deploy)

## 1) Product requirements
- Model: `meta-llama/Llama-3.1-8B-Instruct`
- Alternative larger model: `meta-llama/Llama-3.1-70B-Instruct` (requires bigger GPU and higher cost)
- Target steady QPS:
- Peak QPS:
- Max p95 latency (seconds):
- Max context length:
- Monthly budget (USD):
- Availability objective (e.g. 99.9%):

## 2) API contract
- Interface style: OpenAI-compatible `/v1/chat/completions`
- Auth mechanism: API key via `Authorization: Bearer <token>`
- Max request body size:
- Timeouts:

## 3) Capacity assumptions
- Approx tokens/s per GPU:
- Parallel requests per pod:
- Initial GPU replicas:
- Scale ceiling GPU replicas:

## 4) Compliance and security
- Allowed source CIDRs for EKS endpoint:
- Secrets KMS key owner:
- Image signing standard:
