# Scaling Strategy Decisions

## The Decision

How should you design your scaling strategy to handle variable AI/ML workloads efficiently while maintaining performance and controlling costs?

## Scaling Dimensions in AI/ML

### 1. Temporal Scaling Patterns

#### Training Workloads
- **Batch Processing**: Predictable resource needs, scheduled execution
- **Experimentation**: Bursty, unpredictable resource demands
- **Hyperparameter Tuning**: Parallel execution of multiple experiments
- **Distributed Training**: Coordinated scaling across multiple nodes

#### Inference Workloads
- **Diurnal Patterns**: Daily traffic cycles (business hours vs. off-hours)
- **Seasonal Patterns**: Monthly/quarterly business cycles
- **Event-Driven Spikes**: Product launches, marketing campaigns
- **Geographic Patterns**: Global user base with timezone variations

### 2. Resource Scaling Strategies

## Horizontal vs. Vertical Scaling

### Horizontal Scaling (Scale Out)

#### When to Choose Horizontal Scaling

**Training Workloads:**
```yaml
# Distributed training with horizontal scaling
apiVersion: ray.io/v1alpha1
kind: RayCluster
metadata:
  name: distributed-training
spec:
  rayVersion: '2.8.0'
  headGroupSpec:
    replicas: 1
    rayStartParams:
      dashboard-host: '0.0.0.0'
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.8.0-gpu
          resources:
            limits:
              nvidia.com/gpu: 1
              memory: "16Gi"
              cpu: "8"
  workerGroupSpecs:
  - replicas: 4  # Scale horizontally
    minReplicas: 1
    maxReplicas: 10
    rayStartParams: {}
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.8.0-gpu
          resources:
            limits:
              nvidia.com/gpu: 1
              memory: "16Gi"
              cpu: "8"
```

**Advantages:**
- Better fault tolerance (failure of one node doesn't stop entire job)
- More flexible resource allocation
- Can leverage spot instances more effectively
- Better cost optimization opportunities

**Disadvantages:**
- Communication overhead between nodes
- More complex orchestration
- Network bandwidth requirements
- Potential data locality issues

#### Inference Workloads Horizontal Scaling

```yaml
# HPA with custom metrics for inference
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-inference-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-inference
  minReplicas: 2
  maxReplicas: 20
  metrics:
  # Request-based scaling
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "10"
  
  # Queue-based scaling
  - type: Pods
    pods:
      metric:
        name: queue_length
      target:
        type: AverageValue
        averageValue: "5"
  
  # GPU utilization scaling
  - type: Pods
    pods:
      metric:
        name: gpu_utilization_percentage
      target:
        type: AverageValue
        averageValue: "70"
  
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 4
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 25
        periodSeconds: 60
```

### Vertical Scaling (Scale Up)

#### When to Choose Vertical Scaling

**Large Model Inference:**
```yaml
# VPA for right-sizing large models
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: large-model-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: large-model-inference
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: inference
      maxAllowed:
        cpu: "32"
        memory: "128Gi"
        nvidia.com/gpu: "8"
      minAllowed:
        cpu: "4"
        memory: "16Gi"
        nvidia.com/gpu: "1"
      controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits
```

**Advantages:**
- Simpler architecture and management
- No communication overhead
- Better for memory-intensive workloads
- Easier debugging and monitoring

**Disadvantages:**
- Single point of failure
- Limited by maximum instance size
- Less cost optimization flexibility
- Potential resource waste

## Advanced Scaling Patterns

### 1. Predictive Scaling

```python
# Predictive scaling implementation
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from kubernetes import client, config

class PredictiveScaler:
    def __init__(self):
        config.load_incluster_config()
        self.apps_v1 = client.AppsV1Api()
        self.custom_api = client.CustomObjectsApi()
        
    def predict_load(self, historical_data, forecast_horizon=3600):
        """Predict load for the next hour based on historical patterns"""
        
        # Prepare features: hour of day, day of week, trend
        df = pd.DataFrame(historical_data)
        df['hour'] = pd.to_datetime(df['timestamp']).dt.hour
        df['day_of_week'] = pd.to_datetime(df['timestamp']).dt.dayofweek
        df['trend'] = range(len(df))
        
        # Train model
        features = ['hour', 'day_of_week', 'trend']
        X = df[features]
        y = df['request_rate']
        
        model = LinearRegression()
        model.fit(X, y)
        
        # Predict next hour
        current_time = pd.Timestamp.now()
        future_features = [[
            current_time.hour,
            current_time.dayofweek,
            len(df)
        ]]
        
        predicted_load = model.predict(future_features)[0]
        return max(predicted_load, 0)  # Ensure non-negative
    
    def calculate_required_replicas(self, predicted_load, target_rps_per_pod=10):
        """Calculate required replicas based on predicted load"""
        required_replicas = int(np.ceil(predicted_load / target_rps_per_pod))
        return max(required_replicas, 1)  # At least 1 replica
    
    def scale_deployment(self, deployment_name, namespace, replicas):
        """Scale deployment to specified replica count"""
        try:
            # Get current deployment
            deployment = self.apps_v1.read_namespaced_deployment(
                name=deployment_name,
                namespace=namespace
            )
            
            # Update replica count
            deployment.spec.replicas = replicas
            
            # Apply update
            self.apps_v1.patch_namespaced_deployment(
                name=deployment_name,
                namespace=namespace,
                body=deployment
            )
            
            print(f"Scaled {deployment_name} to {replicas} replicas")
            return True
            
        except Exception as e:
            print(f"Error scaling deployment: {e}")
            return False
```

### 2. Multi-Dimensional Scaling

```yaml
# KEDA ScaledObject for multi-dimensional scaling
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: multi-dimensional-scaler
spec:
  scaleTargetRef:
    name: llm-inference
  minReplicaCount: 2
  maxReplicaCount: 50
  triggers:
  # Scale based on Prometheus metrics
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: http_requests_per_second
      threshold: '10'
      query: sum(rate(http_requests_total[2m]))
  
  # Scale based on queue length
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: queue_length
      threshold: '5'
      query: avg(queue_length)
  
  # Scale based on GPU utilization
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: gpu_utilization
      threshold: '70'
      query: avg(DCGM_FI_DEV_GPU_UTIL)
  
  # Scale based on SQS queue (for batch processing)
  - type: aws-sqs-queue
    metadata:
      queueURL: https://sqs.us-west-2.amazonaws.com/123456789012/ml-jobs
      queueLength: '5'
      awsRegion: us-west-2
```

### 3. Cost-Aware Scaling

```python
# Cost-aware scaling algorithm
class CostAwareScaler:
    def __init__(self):
        self.instance_costs = {
            'g4dn.xlarge': 0.526,
            'g4dn.2xlarge': 0.752,
            'g4dn.4xlarge': 1.204,
            'p3.2xlarge': 3.06,
            'p3.8xlarge': 12.24
        }
        
        self.performance_metrics = {
            'g4dn.xlarge': {'rps': 10, 'latency': 200},
            'g4dn.2xlarge': {'rps': 18, 'latency': 150},
            'g4dn.4xlarge': {'rps': 35, 'latency': 120},
            'p3.2xlarge': {'rps': 50, 'latency': 80},
            'p3.8xlarge': {'rps': 180, 'latency': 60}
        }
    
    def calculate_cost_efficiency(self, instance_type, required_rps):
        """Calculate cost per request for given instance type"""
        cost_per_hour = self.instance_costs[instance_type]
        rps_capacity = self.performance_metrics[instance_type]['rps']
        
        # Calculate number of instances needed
        instances_needed = max(1, int(np.ceil(required_rps / rps_capacity)))
        
        # Calculate cost per request per hour
        total_cost_per_hour = cost_per_hour * instances_needed
        total_rps_capacity = rps_capacity * instances_needed
        
        cost_per_request = total_cost_per_hour / (total_rps_capacity * 3600)  # per second
        
        return {
            'instances_needed': instances_needed,
            'cost_per_hour': total_cost_per_hour,
            'cost_per_request': cost_per_request,
            'latency': self.performance_metrics[instance_type]['latency']
        }
    
    def recommend_scaling_strategy(self, required_rps, max_latency_ms=500, budget_per_hour=None):
        """Recommend optimal scaling strategy based on requirements"""
        
        recommendations = []
        
        for instance_type in self.instance_costs.keys():
            metrics = self.performance_metrics[instance_type]
            
            # Skip if latency requirement not met
            if metrics['latency'] > max_latency_ms:
                continue
            
            cost_analysis = self.calculate_cost_efficiency(instance_type, required_rps)
            
            # Skip if over budget
            if budget_per_hour and cost_analysis['cost_per_hour'] > budget_per_hour:
                continue
            
            recommendations.append({
                'instance_type': instance_type,
                'instances': cost_analysis['instances_needed'],
                'cost_per_hour': cost_analysis['cost_per_hour'],
                'cost_per_request': cost_analysis['cost_per_request'],
                'latency': cost_analysis['latency']
            })
        
        # Sort by cost efficiency
        recommendations.sort(key=lambda x: x['cost_per_request'])
        
        return recommendations
```

## Scaling for Different Workload Types

### 1. Training Workload Scaling

#### Distributed Training Scaling Strategy

```yaml
# Ray cluster with elastic scaling for training
apiVersion: ray.io/v1alpha1
kind: RayCluster
metadata:
  name: elastic-training-cluster
spec:
  rayVersion: '2.8.0'
  enableInTreeAutoscaling: true
  autoscalerOptions:
    upscalingMode: Default
    idleTimeoutSeconds: 60
    resources:
      limits:
        cpu: "1"
        memory: "2Gi"
      requests:
        cpu: "500m"
        memory: "1Gi"
  
  headGroupSpec:
    replicas: 1
    rayStartParams:
      dashboard-host: '0.0.0.0'
      num-cpus: '0'  # Don't schedule work on head node
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.8.0-gpu
          resources:
            limits:
              cpu: "4"
              memory: "8Gi"
  
  workerGroupSpecs:
  # GPU workers for training
  - replicas: 2
    minReplicas: 1
    maxReplicas: 10
    groupName: gpu-workers
    rayStartParams:
      num-gpus: '1'
    template:
      spec:
        nodeSelector:
          node-class: gpu
        tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.8.0-gpu
          resources:
            limits:
              nvidia.com/gpu: 1
              cpu: "8"
              memory: "32Gi"
  
  # CPU workers for data processing
  - replicas: 4
    minReplicas: 2
    maxReplicas: 20
    groupName: cpu-workers
    rayStartParams:
      num-cpus: '4'
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.8.0
          resources:
            limits:
              cpu: "4"
              memory: "16Gi"
```

#### Hyperparameter Tuning Scaling

```python
# Ray Tune with dynamic resource allocation
import ray
from ray import tune
from ray.tune.schedulers import ASHAScheduler

def train_model(config):
    # Training function that adapts to available resources
    num_workers = ray.cluster_resources().get('GPU', 1)
    
    # Scale training based on available GPUs
    if num_workers >= 4:
        # Use distributed training
        strategy = 'distributed'
        batch_size = config['batch_size'] * num_workers
    else:
        # Use single GPU training
        strategy = 'single'
        batch_size = config['batch_size']
    
    # Training logic here
    return {'accuracy': 0.95, 'loss': 0.05}

# Hyperparameter search with resource-aware scaling
scheduler = ASHAScheduler(
    metric="accuracy",
    mode="max",
    max_t=100,
    grace_period=10,
    reduction_factor=2
)

tuner = tune.Tuner(
    train_model,
    param_space={
        "lr": tune.loguniform(1e-4, 1e-1),
        "batch_size": tune.choice([16, 32, 64, 128]),
        "hidden_size": tune.choice([128, 256, 512])
    },
    tune_config=tune.TuneConfig(
        scheduler=scheduler,
        num_samples=100,
        # Dynamic resource allocation
        resources_per_trial={"cpu": 2, "gpu": 0.5}
    )
)

results = tuner.fit()
```

### 2. Inference Workload Scaling

#### Real-time Inference Scaling

```yaml
# Advanced HPA with multiple metrics and behaviors
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: realtime-inference-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: realtime-inference
  minReplicas: 3  # Always maintain minimum for availability
  maxReplicas: 100
  
  metrics:
  # Primary metric: requests per second
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "15"
  
  # Secondary metric: response time
  - type: Pods
    pods:
      metric:
        name: response_time_p95
      target:
        type: AverageValue
        averageValue: "500"  # 500ms
  
  # Tertiary metric: queue depth
  - type: Pods
    pods:
      metric:
        name: queue_depth
      target:
        type: AverageValue
        averageValue: "10"
  
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30  # Fast scale up
      policies:
      - type: Percent
        value: 200  # Double capacity quickly
        periodSeconds: 30
      - type: Pods
        value: 10   # Add up to 10 pods at once
        periodSeconds: 30
      selectPolicy: Max
    
    scaleDown:
      stabilizationWindowSeconds: 600  # Slow scale down
      policies:
      - type: Percent
        value: 10   # Reduce by 10% at a time
        periodSeconds: 60
      - type: Pods
        value: 2    # Remove max 2 pods at once
        periodSeconds: 60
      selectPolicy: Min
```

#### Batch Inference Scaling

```yaml
# Job-based scaling for batch inference
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-inference
spec:
  parallelism: 10  # Start with 10 parallel workers
  completions: 1000  # Process 1000 items total
  backoffLimit: 3
  
  template:
    spec:
      nodeSelector:
        node-class: gpu
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      
      containers:
      - name: batch-worker
        image: batch-inference:latest
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "16Gi"
            cpu: "4"
          requests:
            nvidia.com/gpu: 1
            memory: "8Gi"
            cpu: "2"
        
        env:
        - name: BATCH_SIZE
          value: "32"
        - name: INPUT_QUEUE
          value: "s3://my-bucket/input/"
        - name: OUTPUT_QUEUE
          value: "s3://my-bucket/output/"
      
      restartPolicy: OnFailure
---
# HPA for the job (if using deployment instead)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: batch-inference-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: batch-inference
  minReplicas: 1
  maxReplicas: 50
  
  metrics:
  # Scale based on SQS queue length
  - type: External
    external:
      metric:
        name: sqs_queue_length
        selector:
          matchLabels:
            queue: batch-inference-queue
      target:
        type: AverageValue
        averageValue: "10"  # 10 messages per pod
```

## Scaling Decision Matrix

### Training Workloads

| Scenario | Recommended Strategy | Reasoning |
|----------|---------------------|-----------|
| **Single Large Model** | Vertical Scaling | Model doesn't parallelize well |
| **Hyperparameter Tuning** | Horizontal Scaling | Multiple independent experiments |
| **Distributed Training** | Horizontal Scaling | Designed for multi-node execution |
| **Data Processing** | Horizontal Scaling | Embarrassingly parallel workload |
| **Experimentation** | Elastic Horizontal | Variable resource needs |

### Inference Workloads

| Scenario | Recommended Strategy | Reasoning |
|----------|---------------------|-----------|
| **Real-time API** | Horizontal Scaling | Need redundancy and load distribution |
| **Batch Processing** | Horizontal Scaling | Process multiple items in parallel |
| **Large Model Serving** | Vertical + Horizontal | Large models need big instances + replicas |
| **Edge Inference** | Vertical Scaling | Resource constraints favor efficiency |
| **Multi-Model Serving** | Horizontal Scaling | Different models can run on different pods |

## Monitoring and Observability for Scaling

### Custom Metrics Collection

```yaml
# ServiceMonitor for custom scaling metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: inference-scaling-metrics
spec:
  selector:
    matchLabels:
      app: llm-inference
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
---
# PrometheusRule for scaling metrics
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scaling-metrics-rules
spec:
  groups:
  - name: scaling.rules
    interval: 15s
    rules:
    # Request rate for scaling
    - record: scaling:request_rate
      expr: rate(http_requests_total[1m])
    
    # Queue length for scaling
    - record: scaling:queue_length
      expr: avg(queue_length)
    
    # GPU utilization for scaling
    - record: scaling:gpu_utilization
      expr: avg(DCGM_FI_DEV_GPU_UTIL)
    
    # Response time percentiles
    - record: scaling:response_time_p95
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[2m]))
    
    # Predictive scaling metric
    - record: scaling:predicted_load
      expr: predict_linear(scaling:request_rate[30m], 300)  # 5 minutes ahead
```

## Cost Impact Analysis

### Scaling Cost Comparison

```python
# Cost analysis for different scaling strategies
def analyze_scaling_costs(workload_pattern, strategies):
    """
    Analyze costs for different scaling strategies
    
    workload_pattern: dict with hourly load values
    strategies: list of scaling strategy configurations
    """
    
    results = {}
    
    for strategy_name, config in strategies.items():
        total_cost = 0
        total_hours = len(workload_pattern)
        
        for hour, load in enumerate(workload_pattern):
            # Calculate required capacity
            if config['type'] == 'horizontal':
                replicas = max(
                    config['min_replicas'],
                    min(
                        config['max_replicas'],
                        int(np.ceil(load / config['capacity_per_replica']))
                    )
                )
                hourly_cost = replicas * config['cost_per_replica_hour']
            
            elif config['type'] == 'vertical':
                # Find appropriate instance size
                required_capacity = load
                instance_size = 'small'
                
                for size, capacity in config['instance_capacities'].items():
                    if capacity >= required_capacity:
                        instance_size = size
                        break
                
                hourly_cost = config['instance_costs'][instance_size]
            
            total_cost += hourly_cost
        
        avg_hourly_cost = total_cost / total_hours
        
        results[strategy_name] = {
            'total_cost': total_cost,
            'avg_hourly_cost': avg_hourly_cost,
            'cost_efficiency': total_cost / sum(workload_pattern)  # cost per unit load
        }
    
    return results

# Example usage
workload_pattern = [10, 15, 20, 50, 80, 100, 120, 100, 80, 50, 30, 20]  # 12 hours

strategies = {
    'horizontal_gpu': {
        'type': 'horizontal',
        'min_replicas': 2,
        'max_replicas': 20,
        'capacity_per_replica': 10,
        'cost_per_replica_hour': 0.526  # g4dn.xlarge
    },
    'vertical_gpu': {
        'type': 'vertical',
        'instance_capacities': {
            'small': 10,
            'medium': 30,
            'large': 80,
            'xlarge': 150
        },
        'instance_costs': {
            'small': 0.526,
            'medium': 1.204,
            'large': 3.06,
            'xlarge': 12.24
        }
    }
}

cost_analysis = analyze_scaling_costs(workload_pattern, strategies)
```

## Next Steps

- Review [Framework Selection](05-framework-selection.md) for software stack decisions
- Explore [Storage Strategies](06-storage-strategies.md) for data management scaling
- Consider [Cost Optimization](10-cost-optimization.md) for budget-aware scaling

## Repository Examples

See scaling implementations:
- **Horizontal Scaling**: [vLLM with HPA](../../blueprints/inference/vllm-rayserve-gpu) 
- **Distributed Training**: [Ray training examples](../../blueprints/training/ray-train-gpu)
- **Elastic Scaling**: [Karpenter configurations](../../infra/base/terraform/karpenter.tf)
