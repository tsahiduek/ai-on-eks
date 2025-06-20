# Cost Optimization Strategies

## The Decision

How can you minimize the total cost of ownership (TCO) for your AI/ML workloads on EKS while maintaining performance and reliability requirements?

## Cost Components Analysis

### EKS Control Plane Costs
- **Fixed Cost**: $0.10/hour per cluster ($73/month)
- **Optimization Strategy**: Consolidate workloads into fewer clusters when possible
- **Break-even Point**: Cost-effective with 3+ production workloads

### Compute Costs (Largest Component)

#### Training Workloads
- **GPU Instances**: 60-80% of total training costs
- **Optimization Opportunities**: 
  - Spot instances: 50-90% savings
  - Right-sizing: 20-40% savings
  - Scheduling optimization: 15-30% savings

#### Inference Workloads
- **Always-on Costs**: Continuous resource consumption
- **Optimization Opportunities**:
  - Autoscaling: 30-60% savings
  - Specialized hardware (Inferentia): 40-70% savings
  - Resource sharing: 20-40% savings

### Storage Costs
- **Model Storage**: S3 costs for model artifacts
- **Training Data**: FSx, EFS, or S3 costs
- **Optimization**: Lifecycle policies, compression, deduplication

### Data Transfer Costs
- **Cross-AZ Traffic**: $0.01/GB
- **Internet Egress**: $0.09/GB
- **Optimization**: VPC endpoints, regional optimization

## Cost Optimization Strategies

### 1. Spot Instance Strategy

#### Training Workloads (Ideal for Spot)
```yaml
# Spot-optimized training node group
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
nodeGroups:
  - name: training-spot
    instanceTypes: 
      - "p3.2xlarge"
      - "p3.8xlarge" 
      - "p4d.24xlarge"
    spot: true
    minSize: 0
    maxSize: 20
    desiredCapacity: 0
    
    # Mixed instance policy for availability
    instancesDistribution:
      maxPrice: 0.50  # Maximum price per hour
      onDemandBaseCapacity: 0
      onDemandPercentageAboveBaseCapacity: 0
      spotInstancePools: 3
```

**Spot Instance Best Practices:**
- Use checkpointing for fault tolerance
- Implement graceful shutdown handling
- Mix multiple instance types for availability
- Monitor spot price trends

#### Spot Interruption Handling
```yaml
# Spot interruption handler
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: spot-interrupt-handler
spec:
  selector:
    matchLabels:
      app: spot-interrupt-handler
  template:
    spec:
      nodeSelector:
        karpenter.sh/capacity-type: spot
      containers:
      - name: spot-interrupt-handler
        image: amazon/aws-node-termination-handler:v1.19.0
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
```

### 2. Right-Sizing Strategy

#### Resource Analysis and Optimization
```python
# Resource utilization analysis script
import kubernetes
import pandas as pd
from datetime import datetime, timedelta

def analyze_resource_utilization(namespace="default", days=7):
    """Analyze resource utilization for right-sizing recommendations"""
    
    # Get resource usage metrics
    metrics = get_pod_metrics(namespace, days)
    
    # Calculate utilization percentiles
    analysis = {
        'cpu_p95': metrics['cpu'].quantile(0.95),
        'memory_p95': metrics['memory'].quantile(0.95),
        'cpu_avg': metrics['cpu'].mean(),
        'memory_avg': metrics['memory'].mean(),
        'recommendations': []
    }
    
    # Generate right-sizing recommendations
    for pod in metrics.groupby('pod_name'):
        pod_name, pod_data = pod
        
        current_cpu_request = get_pod_cpu_request(pod_name)
        current_memory_request = get_pod_memory_request(pod_name)
        
        recommended_cpu = pod_data['cpu'].quantile(0.95) * 1.2  # 20% buffer
        recommended_memory = pod_data['memory'].quantile(0.95) * 1.2
        
        if recommended_cpu < current_cpu_request * 0.8:
            analysis['recommendations'].append({
                'pod': pod_name,
                'type': 'downsize_cpu',
                'current': current_cpu_request,
                'recommended': recommended_cpu,
                'savings': calculate_cost_savings(current_cpu_request, recommended_cpu)
            })
    
    return analysis
```

#### Automated Right-Sizing with VPA
```yaml
# Vertical Pod Autoscaler for right-sizing
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: llm-inference-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-inference
  updatePolicy:
    updateMode: "Auto"  # or "Off" for recommendations only
  resourcePolicy:
    containerPolicies:
    - containerName: inference
      maxAllowed:
        cpu: "8"
        memory: "16Gi"
      minAllowed:
        cpu: "100m"
        memory: "128Mi"
      controlledResources: ["cpu", "memory"]
```

### 3. Autoscaling Optimization

#### Predictive Scaling
```yaml
# Custom metrics for predictive scaling
apiVersion: v1
kind: ConfigMap
metadata:
  name: predictive-scaling-config
data:
  config.yaml: |
    predictive_scaling:
      enabled: true
      metrics:
        - name: request_rate_prediction
          query: predict_linear(http_requests_total[1h], 3600)
        - name: queue_length_prediction
          query: predict_linear(queue_length[30m], 1800)
      
      scaling_rules:
        - metric: request_rate_prediction
          threshold: 100
          scale_up_replicas: 2
        - metric: queue_length_prediction
          threshold: 50
          scale_up_replicas: 3
```

#### Cost-Aware Scaling
```python
# Cost-aware scaling algorithm
class CostAwareScaler:
    def __init__(self):
        self.instance_costs = self.load_instance_costs()
        self.performance_metrics = self.load_performance_metrics()
    
    def calculate_scaling_decision(self, current_load, predicted_load):
        """Calculate optimal scaling decision based on cost and performance"""
        
        options = [
            {'replicas': 1, 'instance_type': 'g4dn.xlarge'},
            {'replicas': 2, 'instance_type': 'g4dn.xlarge'},
            {'replicas': 1, 'instance_type': 'g4dn.2xlarge'},
        ]
        
        best_option = None
        best_score = float('inf')
        
        for option in options:
            cost = self.calculate_cost(option)
            performance = self.calculate_performance(option, predicted_load)
            
            # Cost-performance score (lower is better)
            score = cost / performance if performance > 0 else float('inf')
            
            if score < best_score and performance >= self.min_performance_threshold:
                best_score = score
                best_option = option
        
        return best_option
```

### 4. Storage Cost Optimization

#### S3 Lifecycle Policies
```yaml
# S3 lifecycle policy for model artifacts
apiVersion: v1
kind: ConfigMap
metadata:
  name: s3-lifecycle-policy
data:
  policy.json: |
    {
      "Rules": [
        {
          "ID": "ModelArtifactLifecycle",
          "Status": "Enabled",
          "Filter": {"Prefix": "models/"},
          "Transitions": [
            {
              "Days": 30,
              "StorageClass": "STANDARD_IA"
            },
            {
              "Days": 90,
              "StorageClass": "GLACIER"
            },
            {
              "Days": 365,
              "StorageClass": "DEEP_ARCHIVE"
            }
          ]
        },
        {
          "ID": "TrainingDataLifecycle",
          "Status": "Enabled",
          "Filter": {"Prefix": "training-data/"},
          "Transitions": [
            {
              "Days": 7,
              "StorageClass": "STANDARD_IA"
            },
            {
              "Days": 30,
              "StorageClass": "GLACIER"
            }
          ]
        }
      ]
    }
```

#### Storage Class Optimization
```yaml
# Cost-optimized storage classes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-cost-optimized
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"        # Baseline IOPS
  throughput: "125"   # Baseline throughput
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
# High-performance for training (when needed)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-high-performance
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "16000"       # Maximum IOPS
  throughput: "1000"  # Maximum throughput
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### 5. Specialized Hardware Cost Optimization

#### AWS Inferentia for Cost-Effective Inference
```yaml
# Inferentia-based inference deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cost-optimized-inference
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cost-optimized-inference
  template:
    spec:
      nodeSelector:
        node.kubernetes.io/instance-type: inf2.xlarge
      tolerations:
      - key: aws.amazon.com/neuron
        operator: Exists
        effect: NoSchedule
      containers:
      - name: inference
        image: your-model:inferentia
        resources:
          limits:
            aws.amazon.com/neuron: 1
          requests:
            aws.amazon.com/neuron: 1
```

**Cost Comparison Example:**
- GPU (g4dn.xlarge): $0.526/hour
- Inferentia (inf2.xlarge): $0.76/hour
- Performance: Inferentia often 2-3x better throughput
- **Effective Cost**: 50-70% lower per inference

### 6. Multi-Tenancy for Resource Sharing

#### Namespace-Based Multi-Tenancy
```yaml
# Resource quotas for cost control
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    requests.nvidia.com/gpu: "4"
    limits.nvidia.com/gpu: "4"
    requests.memory: "32Gi"
    requests.cpu: "16"
    persistentvolumeclaims: "10"
---
# Network policy for isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: team-a-isolation
  namespace: team-a
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: team-a
  egress:
  - to: []
```

### 7. Cost Monitoring and Alerting

#### Cost Tracking Dashboard
```yaml
# Prometheus rules for cost tracking
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cost-tracking-rules
spec:
  groups:
  - name: cost.rules
    rules:
    - record: cost:node_hourly_cost
      expr: |
        label_replace(
          label_replace(
            kube_node_info,
            "instance_type", "$1", "node", ".*\\.(.*)$"
          ),
          "hourly_cost", "$1", "instance_type", "(.*)"
        ) * on(instance_type) group_left() instance_cost_per_hour
    
    - record: cost:namespace_hourly_cost
      expr: |
        sum by (namespace) (
          cost:node_hourly_cost * on(node) group_left(namespace)
          (
            sum by (node, namespace) (
              kube_pod_info{pod!=""}
            ) / sum by (node) (
              kube_pod_info{pod!=""}
            )
          )
        )
    
    - alert: HighCostNamespace
      expr: cost:namespace_hourly_cost > 100
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "High cost detected in namespace {{ $labels.namespace }}"
        description: "Namespace {{ $labels.namespace }} is costing ${{ $value }}/hour"
```

#### Automated Cost Optimization
```python
# Automated cost optimization service
class CostOptimizer:
    def __init__(self):
        self.k8s_client = kubernetes.client.ApiClient()
        self.cost_threshold = 1000  # $1000/month
    
    def optimize_deployments(self):
        """Automatically optimize deployments based on usage patterns"""
        
        namespaces = self.get_high_cost_namespaces()
        
        for namespace in namespaces:
            deployments = self.get_deployments(namespace)
            
            for deployment in deployments:
                utilization = self.get_resource_utilization(deployment)
                
                if utilization['cpu'] < 0.3:  # Less than 30% CPU utilization
                    self.recommend_downsize(deployment)
                
                if utilization['memory'] < 0.4:  # Less than 40% memory utilization
                    self.recommend_memory_reduction(deployment)
                
                if self.is_suitable_for_spot(deployment):
                    self.recommend_spot_instances(deployment)
    
    def implement_recommendations(self, recommendations, auto_apply=False):
        """Implement cost optimization recommendations"""
        
        for rec in recommendations:
            if auto_apply and rec['confidence'] > 0.8:
                self.apply_recommendation(rec)
            else:
                self.create_optimization_pr(rec)
```

## Cost Optimization Checklist

### Immediate Actions (0-30 days)
- [ ] Implement spot instances for training workloads
- [ ] Right-size inference deployments based on actual usage
- [ ] Set up resource quotas and limits
- [ ] Configure autoscaling for variable workloads
- [ ] Implement S3 lifecycle policies

### Medium-term Actions (1-3 months)
- [ ] Migrate suitable workloads to Inferentia/Trainium
- [ ] Implement predictive scaling
- [ ] Set up comprehensive cost monitoring
- [ ] Optimize storage usage and access patterns
- [ ] Implement multi-tenancy for resource sharing

### Long-term Actions (3-12 months)
- [ ] Develop cost-aware scheduling algorithms
- [ ] Implement automated cost optimization
- [ ] Evaluate reserved instance purchases
- [ ] Consider multi-region cost optimization
- [ ] Develop cost attribution and chargeback systems

## ROI Calculation Framework

### Training Cost Optimization ROI
```
Baseline Training Cost: $10,000/month
Optimizations:
- Spot instances (70% savings): $7,000 savings
- Right-sizing (30% savings): $900 savings  
- Scheduling optimization (20% savings): $400 savings

Total Monthly Savings: $8,300
Annual Savings: $99,600
Implementation Cost: $20,000
ROI: 398% in first year
```

### Inference Cost Optimization ROI
```
Baseline Inference Cost: $5,000/month
Optimizations:
- Autoscaling (50% savings): $2,500 savings
- Inferentia migration (60% savings): $1,800 savings
- Resource sharing (25% savings): $400 savings

Total Monthly Savings: $4,700
Annual Savings: $56,400
Implementation Cost: $15,000
ROI: 276% in first year
```

## Next Steps

- Review [Infrastructure Architecture Decisions](02-infrastructure-architecture.md) for cost-effective architectures
- Explore [Compute Resource Selection](03-compute-resource-selection.md) for hardware cost optimization
- Consider [Scaling Strategy Decisions](04-scaling-strategies.md) for efficient resource utilization

## Repository Examples

See cost optimization implementations:
- **Spot Instance Training**: [Training with spot instances](../../blueprints/training/ray-train-gpu-spot)
- **Inferentia Inference**: [Cost-effective inference](../../blueprints/inference/vllm-rayserve-inf2)
- **Monitoring Setup**: [Cost tracking dashboards](../../infra/base/kubernetes-addons/prometheus)
