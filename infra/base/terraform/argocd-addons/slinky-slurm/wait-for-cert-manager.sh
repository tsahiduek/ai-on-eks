#!/usr/bin/env bash
set -e

# Wait for cert-manager namespace
attempts=0
until kubectl get namespace cert-manager; do
  attempts=$((attempts + 1))
  if [ $attempts -ge 30 ]; then
    echo "Timeout waiting for cert-manager namespace"
    exit 1
  fi
  echo "Waiting for cert-manager namespace... attempt $attempts"
  sleep 10
done

# Wait for cert-manager deployment
attempts=0
until kubectl get deployment cert-manager -n cert-manager; do
  attempts=$((attempts + 1))
  if [ $attempts -ge 30 ]; then
    echo "Timeout waiting for cert-manager deployment"
    exit 1
  fi
  echo "Waiting for cert-manager deployment... attempt $attempts"
  sleep 10
done

# Wait for cert-manager-webhook deployment
attempts=0
until kubectl get deployment cert-manager-webhook -n cert-manager; do
  attempts=$((attempts + 1))
  if [ $attempts -ge 30 ]; then
    echo "Timeout waiting for cert-manager-webhook deployment"
    exit 1
  fi
  echo "Waiting for cert-manager-webhook deployment... attempt $attempts"
  sleep 10
done

exit 0
