# Framework and Tool Selection

## The Decision

Which AI/ML frameworks and tools should you standardize on for your EKS-based AI platform, and how do these choices impact your infrastructure and operational decisions?

## Framework Landscape Analysis

### Primary Framework Decision: PyTorch vs TensorFlow vs JAX

#### PyTorch Ecosystem

**Strengths:**
- **Research-First Design**: Dynamic computation graphs, intuitive debugging
- **Ecosystem Maturity**: Extensive library ecosystem (Transformers, Lightning, etc.)
- **Industry Adoption**: Dominant in research and increasingly in production
- **Kubernetes Integration**: Excellent support with PyTorch operators

**Infrastructure Implications:**
```yaml
# PyTorch-optimized deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pytorch-inference
spec:
  template:
    spec:
      containers:
      - name: pytorch-model
        image: pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "16Gi"
        env:
        - name: TORCH_CUDA_ARCH_LIST
          value: "7.0;7.5;8.0;8.6"
        - name: PYTORCH_CUDA_ALLOC_CONF
          value: "max_split_size_mb:128"
```

**When to Choose PyTorch:**
- Research-heavy environments
- Need for model experimentation and rapid prototyping
- Large language model deployments
- Teams with strong Python expertise
- Dynamic model architectures

#### TensorFlow Ecosystem

**Strengths:**
- **Production-Ready**: TensorFlow Serving, TFX for MLOps
- **Mobile/Edge**: TensorFlow Lite for edge deployment
- **Distributed Training**: Excellent multi-GPU and multi-node support
- **Ecosystem Integration**: Strong Google Cloud integration

**Infrastructure Implications:**
```yaml
# TensorFlow Serving deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tensorflow-serving
spec:
  template:
    spec:
      containers:
      - name: tf-serving
        image: tensorflow/serving:2.13.0-gpu
        ports:
        - containerPort: 8501  # REST API
        - containerPort: 8500  # gRPC API
        env:
        - name: MODEL_NAME
          value: "my_model"
        - name: MODEL_BASE_PATH
          value: "/models"
        resources:
          limits:
            nvidia.com/gpu: 1
        volumeMounts:
        - name: model-storage
          mountPath: /models
```

**When to Choose TensorFlow:**
- Production-first environments
- Need for mobile/edge deployment
- Strong MLOps requirements
- Existing Google Cloud infrastructure
- Traditional ML workloads (tabular data, time series)

#### JAX Ecosystem

**Strengths:**
- **High Performance**: XLA compilation, automatic differentiation
- **Functional Programming**: Pure functions, easier parallelization
- **Research Innovation**: Cutting-edge research implementations
- **Hardware Optimization**: Excellent TPU support

**Infrastructure Implications:**
```yaml
# JAX deployment with XLA optimization
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jax-inference
spec:
  template:
    spec:
      containers:
      - name: jax-model
        image: jax-inference:latest
        env:
        - name: XLA_FLAGS
          value: "--xla_gpu_cuda_data_dir=/usr/local/cuda"
        - name: JAX_ENABLE_X64
          value: "True"
        resources:
          limits:
            nvidia.com/gpu: 1
```

**When to Choose JAX:**
- High-performance computing requirements
- Research environments with cutting-edge needs
- TPU-based deployments
- Functional programming preferences
- Need for automatic parallelization

## Framework Selection Decision Matrix

| Criteria | PyTorch | TensorFlow | JAX |
|----------|---------|------------|-----|
| **Learning Curve** | Medium | Medium-High | High |
| **Research Support** | Excellent | Good | Excellent |
| **Production Readiness** | Good | Excellent | Fair |
| **Community Size** | Large | Large | Growing |
| **Industry Adoption** | High | High | Emerging |
| **Kubernetes Integration** | Excellent | Excellent | Good |
| **Hardware Support** | Broad | Broad | GPU/TPU focused |
| **Debugging Experience** | Excellent | Good | Good |
| **Mobile/Edge Support** | Fair | Excellent | Limited |
| **MLOps Ecosystem** | Growing | Mature | Limited |

## Infrastructure Impact Analysis

### Container Image Strategy

#### Multi-Framework Support
```dockerfile
# Multi-framework base image
FROM nvidia/cuda:11.8-cudnn8-devel-ubuntu20.04

# Install common dependencies
RUN apt-get update && apt-get install -y \
    python3.9 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install frameworks
RUN pip install torch==2.1.0 torchvision torchaudio \
    tensorflow==2.13.0 \
    jax[cuda11_pip]==0.4.13 -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

# Framework-specific optimizations
ENV TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6"
ENV TF_FORCE_GPU_ALLOW_GROWTH=true
ENV XLA_FLAGS="--xla_gpu_cuda_data_dir=/usr/local/cuda"

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
CMD ["python", "serve.py"]
```

#### Framework-Specific Images
```yaml
# Framework-specific image strategy
apiVersion: v1
kind: ConfigMap
metadata:
  name: framework-images
data:
  pytorch: "pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime"
  tensorflow: "tensorflow/tensorflow:2.13.0-gpu"
  jax: "gcr.io/deeplearning-platform-release/jax-cuda:latest"
  huggingface: "huggingface/transformers-pytorch-gpu:4.21.0"
  ray: "rayproject/ray-ml:2.8.0-gpu"
```

### Resource Requirements by Framework

```yaml
# Framework-specific resource profiles
apiVersion: v1
kind: ConfigMap
metadata:
  name: framework-resources
data:
  pytorch-small.yaml: |
    resources:
      limits:
        nvidia.com/gpu: 1
        memory: "8Gi"
        cpu: "4"
      requests:
        nvidia.com/gpu: 1
        memory: "4Gi"
        cpu: "2"
  
  tensorflow-serving.yaml: |
    resources:
      limits:
        nvidia.com/gpu: 1
        memory: "6Gi"
        cpu: "4"
      requests:
        nvidia.com/gpu: 1
        memory: "3Gi"
        cpu: "2"
  
  jax-research.yaml: |
    resources:
      limits:
        nvidia.com/gpu: 1
        memory: "12Gi"
        cpu: "8"
      requests:
        nvidia.com/gpu: 1
        memory: "8Gi"
        cpu: "4"
```

## Tool Selection Decisions

### Inference Serving Tools

#### vLLM vs TensorRT-LLM vs Transformers

**Decision Criteria:**
```python
# Framework compatibility matrix
INFERENCE_TOOLS = {
    'vllm': {
        'frameworks': ['pytorch'],
        'model_types': ['llm', 'chat'],
        'performance': 'high',
        'ease_of_use': 'high',
        'memory_efficiency': 'excellent',
        'cost': 'low'
    },
    'tensorrt_llm': {
        'frameworks': ['pytorch', 'tensorflow'],
        'model_types': ['llm', 'chat', 'embedding'],
        'performance': 'excellent',
        'ease_of_use': 'medium',
        'memory_efficiency': 'excellent',
        'cost': 'low'
    },
    'transformers': {
        'frameworks': ['pytorch', 'tensorflow', 'jax'],
        'model_types': ['all'],
        'performance': 'medium',
        'ease_of_use': 'excellent',
        'memory_efficiency': 'fair',
        'cost': 'high'
    },
    'triton': {
        'frameworks': ['all'],
        'model_types': ['all'],
        'performance': 'high',
        'ease_of_use': 'medium',
        'memory_efficiency': 'good',
        'cost': 'medium'
    }
}

def recommend_inference_tool(requirements):
    """Recommend inference tool based on requirements"""
    scores = {}
    
    for tool, capabilities in INFERENCE_TOOLS.items():
        score = 0
        
        # Framework compatibility
        if requirements['framework'] in capabilities['frameworks'] or 'all' in capabilities['frameworks']:
            score += 3
        
        # Model type support
        if requirements['model_type'] in capabilities['model_types'] or 'all' in capabilities['model_types']:
            score += 3
        
        # Performance requirements
        perf_scores = {'low': 1, 'medium': 2, 'high': 3, 'excellent': 4}
        if perf_scores[capabilities['performance']] >= perf_scores[requirements['min_performance']]:
            score += 2
        
        # Ease of use preference
        ease_scores = {'low': 1, 'medium': 2, 'high': 3, 'excellent': 4}
        score += ease_scores[capabilities['ease_of_use']]
        
        scores[tool] = score
    
    return sorted(scores.items(), key=lambda x: x[1], reverse=True)

# Example usage
requirements = {
    'framework': 'pytorch',
    'model_type': 'llm',
    'min_performance': 'high',
    'ease_of_use_priority': True
}

recommendations = recommend_inference_tool(requirements)
print(f"Recommended tools: {recommendations}")
```

### Training Orchestration Tools

#### Kubeflow vs Ray vs Native Kubernetes

**Kubeflow Training Operator:**
```yaml
# PyTorchJob for distributed training
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: pytorch-distributed-training
spec:
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      template:
        spec:
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime
            command: ["python", "train.py"]
            resources:
              limits:
                nvidia.com/gpu: 1
    Worker:
      replicas: 3
      template:
        spec:
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime
            command: ["python", "train.py"]
            resources:
              limits:
                nvidia.com/gpu: 1
```

**Ray Train:**
```yaml
# Ray cluster for training
apiVersion: ray.io/v1alpha1
kind: RayCluster
metadata:
  name: ray-training-cluster
spec:
  rayVersion: '2.8.0'
  headGroupSpec:
    replicas: 1
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.8.0-gpu
  workerGroupSpecs:
  - replicas: 4
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.8.0-gpu
          resources:
            limits:
              nvidia.com/gpu: 1
```

**Decision Matrix:**

| Tool | Learning Curve | Flexibility | Ecosystem | Kubernetes Native |
|------|----------------|-------------|-----------|-------------------|
| **Kubeflow** | High | Medium | Mature | Excellent |
| **Ray** | Medium | High | Growing | Good |
| **Native K8s** | Low | High | Minimal | Excellent |

### MLOps Tool Selection

#### Experiment Tracking: MLflow vs Weights & Biases vs Neptune

```python
# MLOps tool comparison framework
MLOPS_TOOLS = {
    'mlflow': {
        'deployment': 'self-hosted',
        'cost': 'free',
        'kubernetes_integration': 'excellent',
        'features': ['tracking', 'registry', 'serving'],
        'learning_curve': 'low'
    },
    'wandb': {
        'deployment': 'saas',
        'cost': 'paid',
        'kubernetes_integration': 'good',
        'features': ['tracking', 'sweeps', 'artifacts'],
        'learning_curve': 'low'
    },
    'neptune': {
        'deployment': 'saas',
        'cost': 'paid',
        'kubernetes_integration': 'good',
        'features': ['tracking', 'monitoring', 'collaboration'],
        'learning_curve': 'medium'
    }
}

def select_mlops_stack(requirements):
    """Select MLOps tools based on requirements"""
    
    # Experiment tracking
    if requirements['budget'] == 'minimal':
        tracking_tool = 'mlflow'
    elif requirements['team_size'] > 20:
        tracking_tool = 'wandb'  # Better collaboration features
    else:
        tracking_tool = 'mlflow'  # Cost-effective for smaller teams
    
    # Model registry
    if requirements['compliance'] == 'high':
        registry_tool = 'mlflow'  # Self-hosted for compliance
    else:
        registry_tool = tracking_tool  # Use same tool for simplicity
    
    return {
        'tracking': tracking_tool,
        'registry': registry_tool,
        'deployment_strategy': 'kubernetes' if tracking_tool == 'mlflow' else 'hybrid'
    }
```

## Framework Migration Strategies

### PyTorch to TensorFlow Migration

```python
# Model conversion utilities
import torch
import tensorflow as tf
import onnx
import tf2onnx

def pytorch_to_tensorflow(pytorch_model_path, output_path):
    """Convert PyTorch model to TensorFlow"""
    
    # Load PyTorch model
    pytorch_model = torch.load(pytorch_model_path)
    pytorch_model.eval()
    
    # Convert to ONNX first
    dummy_input = torch.randn(1, 3, 224, 224)
    onnx_path = "temp_model.onnx"
    
    torch.onnx.export(
        pytorch_model,
        dummy_input,
        onnx_path,
        export_params=True,
        opset_version=11,
        do_constant_folding=True,
        input_names=['input'],
        output_names=['output']
    )
    
    # Convert ONNX to TensorFlow
    onnx_model = onnx.load(onnx_path)
    tf_rep = tf2onnx.convert.from_onnx(onnx_model)
    
    # Save TensorFlow model
    tf_rep.export_graph(output_path)
    
    return output_path

# Deployment configuration for migrated model
def create_migration_deployment(model_path, framework_from, framework_to):
    """Create deployment configuration for migrated model"""
    
    deployment_config = {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {
            'name': f'migrated-model-{framework_to}',
            'labels': {
                'migration-from': framework_from,
                'migration-to': framework_to
            }
        },
        'spec': {
            'replicas': 1,
            'selector': {
                'matchLabels': {
                    'app': f'migrated-model-{framework_to}'
                }
            },
            'template': {
                'spec': {
                    'containers': [{
                        'name': 'model-server',
                        'image': f'{framework_to}-serving:latest',
                        'env': [
                            {'name': 'MODEL_PATH', 'value': model_path},
                            {'name': 'FRAMEWORK', 'value': framework_to}
                        ]
                    }]
                }
            }
        }
    }
    
    return deployment_config
```

### Gradual Migration Strategy

```yaml
# Blue-green deployment for framework migration
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: framework-migration
spec:
  replicas: 10
  strategy:
    blueGreen:
      activeService: model-service-active
      previewService: model-service-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: model-service-preview
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: model-service-active
  selector:
    matchLabels:
      app: model-service
  template:
    metadata:
      labels:
        app: model-service
    spec:
      containers:
      - name: model-server
        image: new-framework-image:v2.0  # New framework version
        ports:
        - containerPort: 8080
---
# Analysis template for migration validation
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 60s
    count: 5
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{service="{{args.service-name}}",status!~"5.."}[2m])) /
          sum(rate(http_requests_total{service="{{args.service-name}}"}[2m]))
```

## Cost Implications of Framework Choices

### Framework Cost Analysis

```python
# Cost analysis for different framework choices
def analyze_framework_costs(workload_specs, frameworks):
    """Analyze costs for different framework choices"""
    
    cost_analysis = {}
    
    for framework in frameworks:
        # Base infrastructure costs
        base_cost = calculate_base_infrastructure_cost(framework)
        
        # Development costs
        dev_cost = calculate_development_cost(framework, workload_specs)
        
        # Operational costs
        ops_cost = calculate_operational_cost(framework, workload_specs)
        
        # Training costs
        training_cost = calculate_training_cost(framework, workload_specs)
        
        # Inference costs
        inference_cost = calculate_inference_cost(framework, workload_specs)
        
        total_cost = base_cost + dev_cost + ops_cost + training_cost + inference_cost
        
        cost_analysis[framework] = {
            'base_infrastructure': base_cost,
            'development': dev_cost,
            'operations': ops_cost,
            'training': training_cost,
            'inference': inference_cost,
            'total': total_cost,
            'cost_per_model': total_cost / workload_specs['num_models'],
            'cost_per_request': inference_cost / workload_specs['monthly_requests']
        }
    
    return cost_analysis

# Example framework cost comparison
workload_specs = {
    'num_models': 10,
    'monthly_requests': 1000000,
    'team_size': 15,
    'training_hours_per_month': 500
}

frameworks = ['pytorch', 'tensorflow', 'jax']
cost_comparison = analyze_framework_costs(workload_specs, frameworks)

# Generate cost report
for framework, costs in cost_comparison.items():
    print(f"\n{framework.upper()} Cost Analysis:")
    print(f"  Total Monthly Cost: ${costs['total']:,.2f}")
    print(f"  Cost per Model: ${costs['cost_per_model']:,.2f}")
    print(f"  Cost per 1K Requests: ${costs['cost_per_request']*1000:.4f}")
```

## Framework Selection Recommendations

### By Use Case

**Research and Experimentation:**
- **Primary**: PyTorch (flexibility, debugging)
- **Secondary**: JAX (cutting-edge research)
- **Tools**: Jupyter, Weights & Biases, Ray

**Production Inference:**
- **Primary**: PyTorch + vLLM (LLMs) or TensorFlow Serving (traditional ML)
- **Secondary**: ONNX Runtime (cross-platform)
- **Tools**: Triton, Prometheus, Grafana

**Edge Deployment:**
- **Primary**: TensorFlow Lite
- **Secondary**: ONNX Runtime
- **Tools**: TensorFlow Serving, custom optimizations

**High-Performance Computing:**
- **Primary**: JAX
- **Secondary**: PyTorch with optimizations
- **Tools**: XLA, custom CUDA kernels

### By Team Profile

**ML Research Team:**
```yaml
recommended_stack:
  framework: pytorch
  training: ray
  experimentation: jupyter + wandb
  serving: vllm
  infrastructure: minimal_ops
```

**Production ML Team:**
```yaml
recommended_stack:
  framework: tensorflow
  training: kubeflow
  experimentation: mlflow
  serving: tensorflow_serving
  infrastructure: full_mlops
```

**Startup/Small Team:**
```yaml
recommended_stack:
  framework: pytorch
  training: native_kubernetes
  experimentation: mlflow
  serving: transformers
  infrastructure: cost_optimized
```

## Next Steps

- Review [Storage Strategy Decisions](06-storage-strategies.md) for data management
- Explore [Observability Choices](07-observability-choices.md) for monitoring frameworks
- Consider [Cost Optimization](10-cost-optimization.md) for framework-specific optimizations

## Repository Examples

See framework implementations:
- **PyTorch Examples**: [vLLM deployments](../../blueprints/inference/vllm-rayserve-gpu)
- **Multi-Framework**: [Triton server](../../blueprints/inference/vllm-nvidia-triton-server-gpu)
- **Training Examples**: [Ray training](../../blueprints/training/ray-train-gpu)
