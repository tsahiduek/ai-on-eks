# Exercise 1: Deploy Your First LLM 🟢

**Objective**: Deploy a small language model using vLLM on EKS, configure autoscaling, and test inference endpoints.

**Difficulty**: Beginner  
**Estimated Time**: 60-90 minutes  
**Prerequisites**: EKS cluster with GPU nodes set up

## What You'll Learn

- How to deploy a language model using vLLM and Ray Serve
- Configure Horizontal Pod Autoscaler for inference workloads
- Set up monitoring and observability for model serving
- Test and validate model inference endpoints
- Optimize deployment for cost and performance

## Prerequisites

- EKS cluster with GPU-enabled nodes (g4dn.xlarge or similar)
- kubectl configured to access your cluster
- Helm installed
- Basic understanding of Kubernetes deployments

## Step 1: Prepare Your Environment

First, let's set up the namespace and verify GPU availability:

```bash
# Create namespace for this exercise
kubectl create namespace llm-exercise

# Verify GPU nodes are available
kubectl get nodes -l node-class=gpu
kubectl describe nodes | grep nvidia.com/gpu
```

Expected output should show available GPU resources.

## Step 2: Deploy vLLM with Ray Serve

We'll use the repository's vLLM blueprint as a starting point:

```bash
# Navigate to the vLLM blueprint
cd blueprints/inference/vllm-rayserve-gpu

# Review the configuration
cat values.yaml
```

Create a custom values file for this exercise:

```yaml
# custom-values.yaml
image:
  repository: rayproject/ray-ml
  tag: "2.8.0-gpu"

model:
  name: "microsoft/DialoGPT-small"  # Small model for learning
  max_model_len: 1024
  tensor_parallel_size: 1

resources:
  limits:
    nvidia.com/gpu: 1
    memory: "8Gi"
    cpu: "4"
  requests:
    nvidia.com/gpu: 1
    memory: "4Gi"
    cpu: "2"

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70

service:
  type: LoadBalancer
  port: 8000

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
```

Deploy the model:

```bash
# Install using Helm
helm install llm-exercise . \
  --namespace llm-exercise \
  --values custom-values.yaml

# Watch the deployment
kubectl get pods -n llm-exercise -w
```

## Step 3: Verify Deployment

Check that all components are running:

```bash
# Check pods status
kubectl get pods -n llm-exercise

# Check services
kubectl get svc -n llm-exercise

# Check logs
kubectl logs -n llm-exercise deployment/llm-exercise-vllm
```

## Step 4: Test the Model Endpoint

Get the service endpoint:

```bash
# Get the LoadBalancer URL
kubectl get svc -n llm-exercise llm-exercise-vllm

# If using LoadBalancer, get external IP
EXTERNAL_IP=$(kubectl get svc -n llm-exercise llm-exercise-vllm -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Model endpoint: http://$EXTERNAL_IP:8000"
```

If you don't have a LoadBalancer, use port forwarding:

```bash
# Port forward to access locally
kubectl port-forward -n llm-exercise svc/llm-exercise-vllm 8000:8000
```

Test the inference endpoint:

```bash
# Test with curl
curl -X POST "http://localhost:8000/v1/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "microsoft/DialoGPT-small",
    "prompt": "Hello, how are you?",
    "max_tokens": 50,
    "temperature": 0.7
  }'
```

Expected response:
```json
{
  "id": "cmpl-...",
  "object": "text_completion",
  "created": 1234567890,
  "model": "microsoft/DialoGPT-small",
  "choices": [
    {
      "text": " I'm doing well, thank you for asking!",
      "index": 0,
      "logprobs": null,
      "finish_reason": "stop"
    }
  ]
}
```

## Step 5: Load Testing and Autoscaling

Create a simple load test to trigger autoscaling:

```python
# load_test.py
import asyncio
import aiohttp
import time
import json

async def send_request(session, url, prompt):
    payload = {
        "model": "microsoft/DialoGPT-small",
        "prompt": prompt,
        "max_tokens": 30,
        "temperature": 0.7
    }
    
    try:
        async with session.post(url, json=payload) as response:
            result = await response.json()
            return response.status, result
    except Exception as e:
        return 500, str(e)

async def load_test(url, num_requests=50, concurrency=10):
    prompts = [
        "Hello, how are you?",
        "What's the weather like?",
        "Tell me a joke",
        "How do I cook pasta?",
        "What is machine learning?"
    ]
    
    connector = aiohttp.TCPConnector(limit=concurrency)
    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = []
        
        for i in range(num_requests):
            prompt = prompts[i % len(prompts)]
            task = send_request(session, url, prompt)
            tasks.append(task)
        
        start_time = time.time()
        results = await asyncio.gather(*tasks)
        end_time = time.time()
        
        successful = sum(1 for status, _ in results if status == 200)
        failed = num_requests - successful
        
        print(f"Load test completed in {end_time - start_time:.2f} seconds")
        print(f"Successful requests: {successful}")
        print(f"Failed requests: {failed}")
        print(f"Requests per second: {num_requests / (end_time - start_time):.2f}")

if __name__ == "__main__":
    url = "http://localhost:8000/v1/completions"
    asyncio.run(load_test(url))
```

Run the load test:

```bash
# Install required packages
pip install aiohttp asyncio

# Run load test
python load_test.py
```

Monitor autoscaling:

```bash
# Watch HPA status
kubectl get hpa -n llm-exercise -w

# Watch pod scaling
kubectl get pods -n llm-exercise -w

# Check resource usage
kubectl top pods -n llm-exercise
```

## Step 6: Set Up Monitoring

Create a Grafana dashboard for your LLM deployment:

```yaml
# monitoring-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: llm-dashboard
  namespace: llm-exercise
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "LLM Inference Monitoring",
        "panels": [
          {
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(http_requests_total{job=\"llm-exercise-vllm\"}[5m])",
                "legendFormat": "Requests/sec"
              }
            ]
          },
          {
            "title": "Response Time",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"llm-exercise-vllm\"}[5m]))",
                "legendFormat": "95th percentile"
              }
            ]
          },
          {
            "title": "GPU Utilization",
            "type": "graph",
            "targets": [
              {
                "expr": "DCGM_FI_DEV_GPU_UTIL",
                "legendFormat": "GPU {{gpu}}"
              }
            ]
          }
        ]
      }
    }
```

```bash
# Apply monitoring configuration
kubectl apply -f monitoring-config.yaml
```

## Step 7: Performance Optimization

Let's optimize the deployment for better performance:

```yaml
# optimized-values.yaml
model:
  name: "microsoft/DialoGPT-small"
  max_model_len: 1024
  tensor_parallel_size: 1
  # Add performance optimizations
  max_num_seqs: 256
  max_num_batched_tokens: 2048

resources:
  limits:
    nvidia.com/gpu: 1
    memory: "8Gi"
    cpu: "4"
  requests:
    nvidia.com/gpu: 1
    memory: "6Gi"  # Increased for better performance
    cpu: "3"

# Optimize autoscaling
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 60  # Lower threshold for faster scaling
  
  # Add custom metrics scaling
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60

# Add node affinity for GPU nodes
nodeSelector:
  node-class: gpu

tolerations:
- key: nvidia.com/gpu
  operator: Exists
  effect: NoSchedule
```

Update the deployment:

```bash
# Upgrade with optimized configuration
helm upgrade llm-exercise . \
  --namespace llm-exercise \
  --values optimized-values.yaml

# Monitor the upgrade
kubectl rollout status deployment/llm-exercise-vllm -n llm-exercise
```

## Verification Checklist

Verify your deployment meets these criteria:

- [ ] Model is successfully deployed and responding to requests
- [ ] Autoscaling is configured and working (test with load)
- [ ] Monitoring metrics are being collected
- [ ] Response times are reasonable (< 2 seconds for small prompts)
- [ ] GPU utilization is visible in monitoring
- [ ] Pods are scheduled on GPU nodes only

## Challenge Tasks 🔴

Now that you have a basic deployment working, try these advanced challenges:

### Challenge 1: Multi-Model Deployment
Deploy two different models and implement load balancing between them:

```yaml
# multi-model-values.yaml
models:
  - name: "microsoft/DialoGPT-small"
    replicas: 2
  - name: "microsoft/DialoGPT-medium"
    replicas: 1

# Implement routing logic
routing:
  strategy: "round-robin"  # or "model-specific"
```

### Challenge 2: Cost Optimization
Implement spot instance usage and right-sizing:

1. Configure node groups to use spot instances
2. Implement graceful handling of spot interruptions
3. Right-size resources based on actual usage
4. Target: Reduce costs by 40% while maintaining performance

### Challenge 3: Advanced Monitoring
Set up comprehensive monitoring with:

1. Custom metrics for model-specific KPIs
2. Alerting for high latency or error rates
3. Cost tracking and optimization alerts
4. Predictive scaling based on usage patterns

### Challenge 4: A/B Testing
Implement A/B testing between model versions:

1. Deploy two versions of the same model
2. Route traffic based on user segments
3. Collect metrics for comparison
4. Implement automated rollback on performance degradation

## Troubleshooting

### Common Issues

**Pod stuck in Pending state:**
```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod <pod-name> -n llm-exercise

# Verify GPU availability
kubectl get nodes -o yaml | grep nvidia.com/gpu
```

**Model loading errors:**
```bash
# Check pod logs
kubectl logs -n llm-exercise deployment/llm-exercise-vllm

# Common issues:
# - Insufficient GPU memory
# - Model download failures
# - Incorrect model name
```

**Autoscaling not working:**
```bash
# Check HPA status
kubectl describe hpa -n llm-exercise

# Verify metrics server
kubectl get pods -n kube-system | grep metrics-server

# Check resource requests are set
kubectl describe deployment llm-exercise-vllm -n llm-exercise
```

**High latency responses:**
```bash
# Check GPU utilization
kubectl exec -n llm-exercise <pod-name> -- nvidia-smi

# Monitor resource usage
kubectl top pods -n llm-exercise

# Check for resource throttling
kubectl describe pod <pod-name> -n llm-exercise
```

## Clean Up

When you're done with the exercise:

```bash
# Delete the deployment
helm uninstall llm-exercise -n llm-exercise

# Delete the namespace
kubectl delete namespace llm-exercise

# Verify cleanup
kubectl get all -n llm-exercise
```

## Next Steps

Congratulations! You've successfully deployed your first LLM on EKS. Next, try:

1. **[Exercise 2: Set Up Distributed Training](02-distributed-training.md)** - Learn to train models at scale
2. **[Exercise 3: Multi-Model Serving Platform](03-multi-model-serving.md)** - Deploy multiple models efficiently
3. **[Exercise 5: Production Monitoring Setup](05-production-monitoring.md)** - Set up comprehensive monitoring

## Key Takeaways

- vLLM provides efficient LLM serving with built-in optimizations
- Proper resource allocation is crucial for GPU workloads
- Autoscaling helps manage variable inference loads
- Monitoring is essential for production deployments
- Load testing helps validate performance and scaling behavior

## Share Your Results

Share your experience with the community:
- Post your monitoring dashboards
- Share performance benchmarks
- Contribute improvements to the blueprint
- Help others in GitHub Discussions
