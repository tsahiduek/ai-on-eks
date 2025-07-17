#!/bin/bash
kubectl get service slurm-login -n slurm >/dev/null 2>&1 && \
kubectl patch service slurm-login -n slurm -p '{"spec":{"type":"ClusterIP"}}' || true

cd terraform/_LOCAL/

./cleanup.sh