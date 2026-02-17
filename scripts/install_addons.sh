#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <cluster-name> <region> <lb-controller-irsa-role-arn>"
  exit 1
fi

CLUSTER_NAME="$1"
REGION="$2"
LB_ROLE_ARN="$3"

helm repo add eks https://aws.github.io/eks-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add nvidia https://nvidia.github.io/k8s-device-plugin
helm repo add kedacore https://kedacore.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$LB_ROLE_ARN" \
  --set region="$REGION" \
  --set vpcId=""

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system

helm upgrade --install nvidia-device-plugin nvidia/nvidia-device-plugin \
  --namespace kube-system \
  --set gfd.enabled=true

helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --create-namespace

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword='ChangeMeImmediately123!'

echo "Add-ons installed. Install Cluster Autoscaler or Karpenter next based on your scaling preference."
