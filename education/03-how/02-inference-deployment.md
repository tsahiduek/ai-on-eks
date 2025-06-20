# Deploying Inference Workloads

This guide shows you how to deploy production-ready inference workloads on EKS using the blueprints from this repository.

## Prerequisites

- EKS cluster with GPU nodes set up (see [Cluster Setup](01-cluster-setup.md))
- kubectl configured to access your cluster
- Helm 3.x installed
- Docker for local testing

## Overview

We'll deploy several inference patterns:
1. Single model serving with vLLM
2. Multi-model serving with NVIDIA Triton
3. Autoscaling configuration
4. Monitoring and observability
5. Load balancing and traffic management

## Option 1: vLLM Inference Deployment

### Step 1: Choose Your Model and Blueprint

Navigate to the vLLM blueprint:

```bash
cd blueprints/inference/vllm-rayserve-gpu
ls -la
```

Review available configurations:
- `values.yaml` - Default configuration
- `examples/` - Example configurations for different models

### Step 2: Configure Your Deployment

Create a custom values file for your model:

```yaml
# my-llm-values.yaml
image:
  repository: rayproject/ray-ml
  tag: "2.8.0-gpu"

model:
  name: "meta-llama/Llama-2-7b-chat-hf"  # Your chosen model
  max_model_len: 4096
  tensor_parallel_size: 1
  trust_remote_code: true

# Resource configuration
resources:
  limits:
    nvidia.com/gpu: 1
    memory: "24Gi"
    cpu: "8"
  requests:
    nvidia.com/gpu: 1
    memory: "16Gi"
    cpu: "4"

# Autoscaling configuration
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  
  # Custom metrics scaling
  customMetrics:
    - type: Pods
      pods:
        metric:
          name: requests_per_second
        target:
          type: AverageValue
          averageValue: "10"

# Service configuration
service:
  type: ClusterIP  # Use LoadBalancer for external access
  port: 8000

# Ingress configuration (optional)
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /health
  hosts:
    - host: llm-api.yourdomain.com
      paths:
        - path: /
          pathType: Prefix

# Node selection
nodeSelector:
  node-class: gpu
  workload-type: inference

tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule

# Monitoring
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

### Step 3: Deploy the Model

```bash
# Create namespace
kubectl create namespace llm-inference

# Deploy using Helm
helm install llama-7b . \
  --namespace llm-inference \
  --values my-llm-values.yaml

# Monitor deployment
kubectl get pods -n llm-inference -w
```

### Step 4: Verify Deployment

```bash
# Check pod status
kubectl get pods -n llm-inference

# Check logs
kubectl logs -n llm-inference deployment/llama-7b-vllm

# Check service
kubectl get svc -n llm-inference
```

### Step 5: Test the Inference Endpoint

```bash
# Port forward for testing
kubectl port-forward -n llm-inference svc/llama-7b-vllm 8000:8000

# Test with curl
curl -X POST "http://localhost:8000/v1/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-2-7b-chat-hf",
    "prompt": "Explain machine learning in simple terms:",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

## Option 2: NVIDIA Triton Multi-Model Serving

### Step 1: Prepare Model Repository

Create a model repository structure:

```bash
# Create model repository
mkdir -p model-repository/bert/1
mkdir -p model-repository/gpt2/1

# Example model configuration for BERT
cat > model-repository/bert/config.pbtxt << EOF
name: "bert"
platform: "pytorch_libtorch"
max_batch_size: 8
input [
  {
    name: "input_ids"
    data_type: TYPE_INT64
    dims: [ -1 ]
  }
]
output [
  {
    name: "output"
    data_type: TYPE_FP32
    dims: [ -1, 768 ]
  }
]
EOF
```

### Step 2: Deploy Triton Server

Navigate to the Triton blueprint:

```bash
cd blueprints/inference/vllm-nvidia-triton-server-gpu
```

Configure Triton deployment:

```yaml
# triton-values.yaml
image:
  repository: nvcr.io/nvidia/tritonserver
  tag: "23.04-py3"

# Model repository configuration
modelRepository:
  # Use S3 for model storage
  s3:
    bucket: "your-model-bucket"
    prefix: "models/"
    region: "us-west-2"
  
  # Or use persistent volume
  # persistentVolume:
  #   storageClass: "efs"
  #   size: "100Gi"

# Resource configuration
resources:
  limits:
    nvidia.com/gpu: 1
    memory: "16Gi"
    cpu: "8"
  requests:
    nvidia.com/gpu: 1
    memory: "8Gi"
    cpu: "4"

# Triton configuration
triton:
  # Enable model management
  modelControlMode: "explicit"
  
  # Logging configuration
  logLevel: "INFO"
  logVerbose: 1
  
  # Performance settings
  strictModelConfig: false
  strictReadiness: false

# Service configuration
service:
  type: ClusterIP
  ports:
    http: 8000
    grpc: 8001
    metrics: 8002

# Autoscaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Monitoring
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
```

Deploy Triton:

```bash
# Deploy Triton server
helm install triton-server . \
  --namespace llm-inference \
  --values triton-values.yaml

# Verify deployment
kubectl get pods -n llm-inference
kubectl logs -n llm-inference deployment/triton-server
```

### Step 3: Load Models Dynamically

```bash
# Load a model
curl -X POST "http://localhost:8000/v2/repository/models/bert/load"

# Check model status
curl "http://localhost:8000/v2/models/bert"

# List all models
curl "http://localhost:8000/v2/models"
```

## Autoscaling Configuration

### Horizontal Pod Autoscaler (HPA)

```yaml
# hpa-custom-metrics.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-inference-hpa
  namespace: llm-inference
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llama-7b-vllm
  minReplicas: 1
  maxReplicas: 10
  metrics:
  # CPU-based scaling
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  
  # Memory-based scaling
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  
  # Custom metrics scaling
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "10"
  
  # GPU utilization scaling
  - type: Pods
    pods:
      metric:
        name: gpu_utilization
      target:
        type: AverageValue
        averageValue: "80"

  # Scaling behavior
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
```

Apply the HPA:

```bash
kubectl apply -f hpa-custom-metrics.yaml
```

### Vertical Pod Autoscaler (VPA)

```yaml
# vpa-inference.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: llm-inference-vpa
  namespace: llm-inference
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llama-7b-vllm
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: vllm
      maxAllowed:
        cpu: "16"
        memory: "32Gi"
        nvidia.com/gpu: "1"
      minAllowed:
        cpu: "2"
        memory: "4Gi"
        nvidia.com/gpu: "1"
      controlledResources: ["cpu", "memory"]
```

## Load Balancing and Traffic Management

### Application Load Balancer (ALB)

```yaml
# alb-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: llm-inference-ingress
  namespace: llm-inference
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
    
    # SSL configuration
    alb.ingress.kubernetes.io/certificate-arn: arn
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    
    # Load balancing
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
    
spec:
  rules:
  - host: api.yourdomain.com
    http:
      paths:
      - path: /v1/completions
        pathType: Prefix
        backend:
          service:
            name: llama-7b-vllm
            port:
              number: 8000
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: triton-server
            port:
              number: 8000
```

### Service Mesh (Optional - Istio)

```yaml
# istio-virtual-service.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: llm-inference-vs
  namespace: llm-inference
spec:
  hosts:
  - api.yourdomain.com
  gateways:
  - llm-gateway
  http:
  # A/B testing between model versions
  - match:
    - headers:
        x-model-version:
          exact: "v2"
    route:
    - destination:
        host: llama-7b-vllm-v2
        port:
          number: 8000
      weight: 100
  
  # Default routing
  - route:
    - destination:
        host: llama-7b-vllm
        port:
          number: 8000
      weight: 90
    - destination:
        host: llama-7b-vllm-v2
        port:
          number: 8000
      weight: 10
    
    # Fault injection for testing
    fault:
      delay:
        percentage:
          value: 0.1
        fixedDelay: 5s
```

## Monitoring and Observability

### Prometheus Metrics Collection

```yaml
# prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-inference-config
  namespace: monitoring
data:
  inference-rules.yaml: |
    groups:
    - name: inference.rules
      rules:
      # Request rate
      - record: inference:request_rate
        expr: rate(http_requests_total{job="llm-inference"}[5m])
      
      # Response time percentiles
      - record: inference:response_time_p95
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="llm-inference"}[5m]))
      
      # GPU utilization
      - record: inference:gpu_utilization
        expr: avg(DCGM_FI_DEV_GPU_UTIL{job="gpu-metrics"})
      
      # Model-specific metrics
      - record: inference:tokens_per_second
        expr: rate(vllm_tokens_generated_total[5m])
      
      # Error rate
      - record: inference:error_rate
        expr: rate(http_requests_total{job="llm-inference",status=~"5.."}[5m]) / rate(http_requests_total{job="llm-inference"}[5m])
      
      # Alerts
      - alert: HighInferenceLatency
        expr: inference:response_time_p95 > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High inference latency detected"
          description: "95th percentile response time is {{ $value }}s"
      
      - alert: HighErrorRate
        expr: inference:error_rate > 0.05
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "High error rate in inference service"
          description: "Error rate is {{ $value | humanizePercentage }}"
```

### Grafana Dashboard

```json
{
  "dashboard": {
    "title": "LLM Inference Dashboard",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "inference:request_rate",
            "legendFormat": "Requests/sec"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "inference:response_time_p95",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "GPU Utilization",
        "type": "graph",
        "targets": [
          {
            "expr": "inference:gpu_utilization",
            "legendFormat": "GPU {{gpu}}"
          }
        ]
      },
      {
        "title": "Tokens per Second",
        "type": "stat",
        "targets": [
          {
            "expr": "inference:tokens_per_second",
            "legendFormat": "Tokens/sec"
          }
        ]
      }
    ]
  }
}
```

## Performance Optimization

### Model Optimization

```python
# model-optimization.py
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

def optimize_model_for_inference(model_path, output_path):
    """Optimize model for inference deployment"""
    
    # Load model
    model = AutoModelForCausalLM.from_pretrained(model_path)
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    
    # Apply optimizations
    model.eval()
    
    # Convert to half precision
    model = model.half()
    
    # Compile with TorchScript
    example_input = tokenizer("Hello world", return_tensors="pt")
    traced_model = torch.jit.trace(model, example_input['input_ids'])
    
    # Save optimized model
    traced_model.save(f"{output_path}/model.pt")
    tokenizer.save_pretrained(output_path)
    
    return traced_model

# Usage
optimize_model_for_inference(
    model_path="meta-llama/Llama-2-7b-chat-hf",
    output_path="./optimized-model"
)
```

### Batch Processing Optimization

```yaml
# batch-inference-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: batch-inference-config
data:
  config.yaml: |
    batch_processing:
      max_batch_size: 32
      batch_timeout_ms: 100
      max_queue_size: 1000
      
    model_config:
      max_model_len: 2048
      tensor_parallel_size: 1
      max_num_seqs: 256
      max_num_batched_tokens: 8192
      
    performance:
      enable_chunked_prefill: true
      max_num_batched_tokens: 8192
      max_paddings: 256
```

## Testing and Validation

### Load Testing

```python
# load-test.py
import asyncio
import aiohttp
import time
import json
from concurrent.futures import ThreadPoolExecutor

async def send_request(session, url, payload):
    try:
        async with session.post(url, json=payload) as response:
            result = await response.json()
            return {
                'status': response.status,
                'latency': response.headers.get('X-Response-Time', 0),
                'tokens': len(result.get('choices', [{}])[0].get('text', '').split())
            }
    except Exception as e:
        return {'status': 500, 'error': str(e)}

async def load_test(url, num_requests=100, concurrency=10):
    payloads = [
        {
            "model": "meta-llama/Llama-2-7b-chat-hf",
            "prompt": f"Test prompt {i}",
            "max_tokens": 50,
            "temperature": 0.7
        }
        for i in range(num_requests)
    ]
    
    connector = aiohttp.TCPConnector(limit=concurrency)
    async with aiohttp.ClientSession(connector=connector) as session:
        start_time = time.time()
        results = await asyncio.gather(*[
            send_request(session, url, payload) 
            for payload in payloads
        ])
        end_time = time.time()
        
        # Analyze results
        successful = [r for r in results if r.get('status') == 200]
        failed = [r for r in results if r.get('status') != 200]
        
        if successful:
            avg_latency = sum(float(r.get('latency', 0)) for r in successful) / len(successful)
            total_tokens = sum(r.get('tokens', 0) for r in successful)
        else:
            avg_latency = 0
            total_tokens = 0
        
        print(f"Load test completed in {end_time - start_time:.2f} seconds")
        print(f"Successful requests: {len(successful)}")
        print(f"Failed requests: {len(failed)}")
        print(f"Average latency: {avg_latency:.2f}ms")
        print(f"Tokens per second: {total_tokens / (end_time - start_time):.2f}")
        print(f"Requests per second: {num_requests / (end_time - start_time):.2f}")

if __name__ == "__main__":
    url = "http://localhost:8000/v1/completions"
    asyncio.run(load_test(url, num_requests=100, concurrency=10))
```

## Troubleshooting

### Common Issues

**Pod OOMKilled:**
```bash
# Check memory usage
kubectl top pods -n llm-inference

# Increase memory limits
kubectl patch deployment llama-7b-vllm -n llm-inference -p '{"spec":{"template":{"spec":{"containers":[{"name":"vllm","resources":{"limits":{"memory":"32Gi"}}}]}}}}'
```

**GPU Out of Memory:**
```bash
# Check GPU usage
kubectl exec -n llm-inference <pod-name> -- nvidia-smi

# Reduce model size or batch size
# Update model configuration
```

**High Latency:**
```bash
# Check resource utilization
kubectl top pods -n llm-inference

# Check for resource throttling
kubectl describe pod <pod-name> -n llm-inference

# Scale up replicas
kubectl scale deployment llama-7b-vllm --replicas=3 -n llm-inference
```

## Next Steps

- Set up [Training Environments](03-training-setup.md) for model training
- Configure [Storage](04-storage-configuration.md) for model artifacts
- Implement [Monitoring](07-monitoring-setup.md) for production observability

## Repository References

This guide uses:
- **vLLM Blueprint**: [/blueprints/inference/vllm-rayserve-gpu](../../blueprints/inference/vllm-rayserve-gpu)
- **Triton Blueprint**: [/blueprints/inference/vllm-nvidia-triton-server-gpu](../../blueprints/inference/vllm-nvidia-triton-server-gpu)
- **Monitoring Setup**: [/infra/base/kubernetes-addons](../../infra/base/kubernetes-addons)
