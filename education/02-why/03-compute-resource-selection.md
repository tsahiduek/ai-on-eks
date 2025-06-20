# Compute Resource Selection

## The Decision

Which compute resources should you choose for your AI/ML workloads on EKS: traditional GPUs, AWS specialized hardware (Trainium/Inferentia), or CPU-only instances?

## Options Available

### 1. NVIDIA GPUs
- **Training**: P3, P4, P5 instances with V100, A100, H100 GPUs
- **Inference**: G4, G5 instances with T4, A10G GPUs
- **Broad compatibility** with AI/ML frameworks
- **Mature ecosystem** and tooling

### 2. AWS Trainium (Training)
- **Purpose-built** for deep learning training
- **Cost-optimized** compared to GPU training
- **High-performance** interconnect with EFA
- **PyTorch and TensorFlow** support

### 3. AWS Inferentia (Inference)
- **Specialized** for inference workloads
- **Cost-effective** for production inference
- **Low latency** and high throughput
- **Optimized** for transformer models

### 4. CPU-Only Instances
- **General-purpose** compute
- **Cost-effective** for smaller models
- **No specialized software** requirements
- **Broad compatibility**

## Decision Framework

### Workload Characteristics Analysis

#### Training Workloads

**Large Model Training (>7B parameters):**
```
Decision Tree:
├── Budget Conscious + PyTorch → AWS Trainium (Trn1)
├── Maximum Performance → NVIDIA H100 (P5)
├── Balanced Performance/Cost → NVIDIA A100 (P4d)
└── Experimentation → NVIDIA V100 (P3)
```

**Medium Model Training (1B-7B parameters):**
```
Decision Tree:
├── Cost Optimization → AWS Trainium (Trn1)
├── Framework Flexibility → NVIDIA A100 (P4d)
├── Quick Experiments → NVIDIA T4 (G4dn)
└── CPU-only Models → High-memory CPU instances (R5, M5)
```

#### Inference Workloads

**High-Throughput Inference:**
```
Decision Tree:
├── Transformer Models + Cost Focus → AWS Inferentia (Inf2)
├── Mixed Model Types → NVIDIA A10G (G5)
├── Real-time Requirements → NVIDIA T4 (G4dn)
└── Simple Models → CPU instances (M5, C5)
```

**Low-Latency Inference:**
```
Decision Tree:
├── Sub-10ms Requirements → NVIDIA A10G (G5)
├── Cost-Optimized → AWS Inferentia (Inf2)
├── Edge Deployment → CPU instances
└── Batch Processing → Any GPU option
```

## Detailed Analysis by Hardware Type

### NVIDIA GPUs

#### When to Choose GPUs

**Advantages:**
- **Ecosystem Maturity**: Extensive tooling and framework support
- **Flexibility**: Works with any AI/ML framework
- **Performance**: Proven performance for diverse workloads
- **Community**: Large community and extensive documentation

**Best For:**
- Research and experimentation
- Mixed workload environments
- Complex model architectures
- Multi-framework requirements

#### GPU Selection Criteria

```yaml
# Training workload GPU selection
Training Requirements:
  Small Models (<1B params):
    - Instance: g4dn.xlarge (T4)
    - Memory: 16GB GPU memory
    - Cost: ~$0.526/hour
    
  Medium Models (1B-10B params):
    - Instance: p3.2xlarge (V100)
    - Memory: 16GB GPU memory
    - Cost: ~$3.06/hour
    
  Large Models (10B+ params):
    - Instance: p4d.24xlarge (A100)
    - Memory: 40GB GPU memory
    - Cost: ~$32.77/hour
    
  Very Large Models (70B+ params):
    - Instance: p5.48xlarge (H100)
    - Memory: 80GB GPU memory
    - Cost: ~$98.32/hour
```

### AWS Trainium

#### When to Choose Trainium

**Advantages:**
- **Cost Efficiency**: Up to 50% cost savings vs. comparable GPU training
- **Purpose-Built**: Optimized specifically for deep learning training
- **Scalability**: Excellent for distributed training with EFA
- **AWS Integration**: Native integration with AWS services

**Limitations:**
- **Framework Support**: Limited to PyTorch and TensorFlow
- **Model Support**: Best for transformer architectures
- **Ecosystem**: Smaller community and tooling ecosystem
- **Debugging**: More complex debugging compared to GPUs

#### Trainium Selection Guide

```yaml
# Trainium instance selection
Trn1 Instances:
  trn1.2xlarge:
    - Trainium chips: 1
    - Memory: 32GB
    - Use case: Small to medium model training
    - Cost: ~$1.34/hour
    
  trn1.32xlarge:
    - Trainium chips: 16
    - Memory: 512GB
    - Use case: Large model distributed training
    - Cost: ~$21.50/hour
```

**Migration Considerations:**
```python
# Example: PyTorch model adaptation for Trainium
import torch
import torch_xla.core.xla_model as xm

# Standard PyTorch training loop
def train_step_gpu(model, data, target):
    output = model(data)
    loss = F.cross_entropy(output, target)
    loss.backward()
    optimizer.step()
    return loss

# Trainium-optimized training loop
def train_step_trainium(model, data, target):
    output = model(data)
    loss = F.cross_entropy(output, target)
    loss.backward()
    xm.optimizer_step(optimizer)  # XLA-optimized step
    return loss
```

### AWS Inferentia

#### When to Choose Inferentia

**Advantages:**
- **Cost Efficiency**: Up to 70% cost savings for inference
- **Latency Optimization**: Optimized for low-latency inference
- **Throughput**: High throughput for batch inference
- **Power Efficiency**: Lower power consumption

**Best For:**
- Production inference workloads
- Transformer model serving
- Cost-sensitive applications
- High-volume inference

#### Inferentia Selection Guide

```yaml
# Inferentia instance selection
Inf2 Instances:
  inf2.xlarge:
    - Inferentia chips: 1
    - Memory: 16GB
    - Use case: Single model inference
    - Cost: ~$0.76/hour
    
  inf2.8xlarge:
    - Inferentia chips: 1
    - Memory: 128GB
    - Use case: Large model inference
    - Cost: ~$2.04/hour
    
  inf2.24xlarge:
    - Inferentia chips: 6
    - Memory: 384GB
    - Use case: Multi-model serving
    - Cost: ~$6.09/hour
```

**Model Optimization Example:**
```python
# Compile model for Inferentia
import torch
import torch_neuron

# Load pre-trained model
model = torch.jit.load('model.pt')

# Compile for Inferentia
model_neuron = torch.neuron.trace(
    model,
    example_inputs,
    compiler_args=['--neuron-optimize=2']
)

# Save compiled model
model_neuron.save('model_neuron.pt')
```

## Cost-Performance Analysis

### Training Cost Comparison

| Workload | GPU Option | Trainium Option | Cost Savings | Performance |
|----------|------------|-----------------|--------------|-------------|
| **7B Model Training** | p3.2xlarge ($3.06/hr) | trn1.2xlarge ($1.34/hr) | 56% | Comparable |
| **13B Model Training** | p4d.24xlarge ($32.77/hr) | trn1.32xlarge ($21.50/hr) | 34% | Comparable |
| **70B Model Training** | 4x p4d.24xlarge ($131/hr) | 2x trn1.32xlarge ($43/hr) | 67% | Comparable |

### Inference Cost Comparison

| Workload | GPU Option | Inferentia Option | Cost Savings | Latency |
|----------|------------|-------------------|--------------|---------|
| **BERT Inference** | g4dn.xlarge ($0.526/hr) | inf2.xlarge ($0.76/hr) | -44% | Better |
| **GPT-3.5 Inference** | g5.2xlarge ($1.21/hr) | inf2.8xlarge ($2.04/hr) | -69% | Better |
| **Large Model Batch** | g5.12xlarge ($5.67/hr) | inf2.24xlarge ($6.09/hr) | -7% | Better |

*Note: Cost savings depend on utilization patterns and specific model characteristics*

## Implementation Strategies

### Multi-Hardware Strategy

```yaml
# Node groups for different hardware types
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
nodeGroups:
  # GPU training nodes
  - name: gpu-training
    instanceTypes: ["p4d.24xlarge"]
    minSize: 0
    maxSize: 4
    labels:
      hardware-type: nvidia-gpu
      workload-type: training
    taints:
      - key: nvidia.com/gpu
        effect: NoSchedule

  # Trainium training nodes
  - name: trainium-training
    instanceTypes: ["trn1.32xlarge"]
    minSize: 0
    maxSize: 2
    labels:
      hardware-type: aws-trainium
      workload-type: training
    taints:
      - key: aws.amazon.com/neuron
        effect: NoSchedule

  # Inferentia inference nodes
  - name: inferentia-inference
    instanceTypes: ["inf2.xlarge", "inf2.8xlarge"]
    minSize: 1
    maxSize: 10
    labels:
      hardware-type: aws-inferentia
      workload-type: inference
    taints:
      - key: aws.amazon.com/neuron
        effect: NoSchedule
```

### Workload Scheduling

```yaml
# Training job with hardware selection
apiVersion: batch/v1
kind: Job
metadata:
  name: llama-training
spec:
  template:
    spec:
      nodeSelector:
        hardware-type: aws-trainium
      tolerations:
      - key: aws.amazon.com/neuron
        operator: Exists
        effect: NoSchedule
      containers:
      - name: training
        image: pytorch/pytorch:latest
        resources:
          limits:
            aws.amazon.com/neuron: 16
---
# Inference deployment with hardware selection
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bert-inference
spec:
  template:
    spec:
      nodeSelector:
        hardware-type: aws-inferentia
      tolerations:
      - key: aws.amazon.com/neuron
        operator: Exists
        effect: NoSchedule
      containers:
      - name: inference
        image: bert-inference:latest
        resources:
          limits:
            aws.amazon.com/neuron: 1
```

## Decision Matrix

### Training Workload Decision Matrix

| Criteria | NVIDIA GPU | AWS Trainium | CPU Only |
|----------|------------|--------------|----------|
| **Cost** | High | Medium | Low |
| **Performance** | Excellent | Excellent | Poor |
| **Framework Support** | Universal | Limited | Universal |
| **Ecosystem** | Mature | Growing | Mature |
| **Debugging** | Easy | Moderate | Easy |
| **Scalability** | Good | Excellent | Poor |

### Inference Workload Decision Matrix

| Criteria | NVIDIA GPU | AWS Inferentia | CPU Only |
|----------|------------|----------------|----------|
| **Cost** | High | Low | Medium |
| **Latency** | Good | Excellent | Poor |
| **Throughput** | Good | Excellent | Poor |
| **Model Support** | Universal | Transformers | Universal |
| **Optimization** | Manual | Automatic | Manual |
| **Deployment** | Standard | Specialized | Standard |

## Migration Strategies

### GPU to Trainium Migration

**Phase 1: Assessment**
```bash
# Analyze current GPU utilization
kubectl top nodes --selector=node-type=gpu
kubectl describe nodes --selector=node-type=gpu

# Review model compatibility
python check_trainium_compatibility.py --model-path ./models/
```

**Phase 2: Pilot Migration**
```yaml
# Create Trainium node group
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
nodeGroups:
  - name: trainium-pilot
    instanceTypes: ["trn1.2xlarge"]
    minSize: 1
    maxSize: 2
    labels:
      migration-phase: pilot
```

**Phase 3: Gradual Rollout**
- Migrate non-critical training jobs first
- Monitor performance and cost metrics
- Gradually increase Trainium usage
- Maintain GPU capacity for fallback

### GPU to Inferentia Migration

**Model Compilation Pipeline**
```python
# Automated model compilation for Inferentia
def compile_for_inferentia(model_path, output_path):
    model = torch.jit.load(model_path)
    
    # Trace and compile
    compiled_model = torch.neuron.trace(
        model,
        example_inputs,
        compiler_args=[
            '--neuron-optimize=2',
            '--auto-cast=none'
        ]
    )
    
    compiled_model.save(output_path)
    return compiled_model
```

## Monitoring and Optimization

### Hardware-Specific Metrics

```yaml
# Prometheus configuration for multi-hardware monitoring
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-hardware-config
data:
  prometheus.yml: |
    scrape_configs:
    # NVIDIA GPU metrics
    - job_name: 'nvidia-dcgm'
      static_configs:
      - targets: ['dcgm-exporter:9400']
      
    # Neuron (Trainium/Inferentia) metrics
    - job_name: 'neuron-monitor'
      static_configs:
      - targets: ['neuron-monitor:8000']
      
    # CPU metrics
    - job_name: 'node-exporter'
      kubernetes_sd_configs:
      - role: endpoints
```

### Cost Optimization Automation

```python
# Automated hardware recommendation system
class HardwareRecommender:
    def __init__(self):
        self.cost_matrix = self.load_cost_matrix()
        self.performance_matrix = self.load_performance_matrix()
    
    def recommend_hardware(self, workload_spec):
        model_size = workload_spec['model_size']
        workload_type = workload_spec['type']  # training/inference
        budget_constraint = workload_spec['budget']
        
        if workload_type == 'training':
            return self._recommend_training_hardware(model_size, budget_constraint)
        else:
            return self._recommend_inference_hardware(model_size, budget_constraint)
    
    def _recommend_training_hardware(self, model_size, budget):
        if model_size > 10e9 and budget == 'cost-optimized':
            return 'aws-trainium'
        elif model_size > 10e9:
            return 'nvidia-a100'
        else:
            return 'nvidia-t4'
```

## Next Steps

- Review [Scaling Strategy Decisions](04-scaling-strategies.md) for workload scaling approaches
- Explore [Cost Optimization Strategies](10-cost-optimization.md) for budget optimization
- Consider [Framework Selection](05-framework-selection.md) for software stack decisions

## Repository Examples

See these hardware-specific implementations:

- **GPU Examples**: [NVIDIA GPU blueprints](../../blueprints/inference/vllm-rayserve-gpu) with optimized configurations
- **Trainium Examples**: [Training on Trainium](../../infra/trainium-inferentia) with distributed setups
- **Inferentia Examples**: [Inference on Inferentia](../../blueprints/inference/vllm-rayserve-inf2) with model optimization
- **Multi-Hardware**: [Mixed hardware deployments](../../infra/base) with node group configurations
