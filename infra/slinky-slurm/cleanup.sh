#!/bin/bash
if kubectl get service slurm-login -n slurm >/dev/null 2>&1; then
  kubectl annotate service slurm-login -n slurm service.beta.kubernetes.io/load-balancer-source-ranges- 2>&1 || true
  kubectl patch service slurm-login -n slurm -p '{"spec":{"type":"ClusterIP"}}' || true
fi

cd terraform/_LOCAL/

./cleanup.sh