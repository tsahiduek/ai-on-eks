# Setting Up Training Environments

This guide shows you how to set up distributed training environments on EKS for AI/ML workloads using Ray, PyTorch, and other frameworks.

## Prerequisites

- EKS cluster with GPU nodes (see [Cluster Setup](01-cluster-setup.md))
- kubectl configured to access your cluster
- Helm 3.x installed
- Understanding of distributed training concepts

## Overview

We'll set up:
1. Ray cluster for distributed training
2. PyTorch distributed training with Kubeflow
3. Data pipeline configuration
4. Experiment tracking and model management
5. Resource optimization for training workloads

## Option 1: Ray Distributed Training

### Step 1: Deploy Ray Cluster

Navigate to the Ray training blueprint:

```bash
cd blueprints/training/ray-train-gpu
```

Create a custom configuration for your training cluster:

```yaml
# ray-training-values.yaml
image:
  repository: rayproject/ray-ml
  tag: "2.8.0-gpu"

cluster:
  enableInTreeAutoscaling: true
  
head:
  replicas: 1
  resources:
    limits:
      cpu: "4"
      memory: "16Gi"
    requests:
      cpu: "2"
      memory: "8Gi"
  rayStartParams:
    dashboard-host: '0.0.0.0'
    num-cpus: '0'  # Don't schedule work on head node

worker:
  # GPU workers for training
  - groupName: gpu-workers
    replicas: 4
    minReplicas: 1
    maxReplicas: 10
    resources:
      limits:
        nvidia.com/gpu: 1
        cpu: "8"
        memory: "32Gi"
      requests:
        nvidia.com/gpu: 1
        cpu: "4"
        memory: "16Gi"
    rayStartParams:
      num-gpus: '1'
    nodeSelector:
      node-class: gpu
    tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  
  # CPU workers for data processing
  - groupName: cpu-workers
    replicas: 2
    minReplicas: 1
    maxReplicas: 20
    resources:
      limits:
        cpu: "8"
        memory: "16Gi"
      requests:
        cpu: "4"
        memory: "8Gi"
    rayStartParams:
      num-cpus: '8'

# Storage configuration
storage:
  # Shared storage for datasets
  datasets:
    storageClass: "efs"
    size: "1Ti"
    accessMode: ReadWriteMany
  
  # High-performance storage for checkpoints
  checkpoints:
    storageClass: "gp3-fast"
    size: "500Gi"
    accessMode: ReadWriteOnce

# Monitoring
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
```

Deploy the Ray cluster:

```bash
# Create namespace
kubectl create namespace ray-training

# Deploy Ray cluster
helm install ray-training . \
  --namespace ray-training \
  --values ray-training-values.yaml

# Verify deployment
kubectl get pods -n ray-training
kubectl get raycluster -n ray-training
```

### Step 2: Set Up Training Job

Create a distributed training script:

```python
# distributed_training.py
import ray
import torch
import torch.nn as nn
from ray import train
from ray.train import Checkpoint
from ray.train.torch import TorchTrainer
from ray.train.torch import TorchConfig
import tempfile
import os

def train_func(config):
    """Training function that runs on each worker"""
    
    # Initialize distributed training
    import torch.distributed as dist
    
    # Get distributed training info
    rank = train.get_context().get_world_rank()
    world_size = train.get_context().get_world_size()
    
    print(f"Worker {rank}/{world_size} starting training")
    
    # Create model
    model = nn.Sequential(
        nn.Linear(784, 128),
        nn.ReLU(),
        nn.Linear(128, 10)
    )
    
    # Wrap model for distributed training
    model = torch.nn.parallel.DistributedDataParallel(model)
    
    # Create optimizer
    optimizer = torch.optim.Adam(model.parameters(), lr=config["lr"])
    
    # Training loop
    for epoch in range(config["num_epochs"]):
        # Simulate training step
        loss = torch.randn(1, requires_grad=True)
        
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        # Report metrics
        train.report({"loss": loss.item(), "epoch": epoch})
        
        # Save checkpoint
        if epoch % 5 == 0:
            with tempfile.TemporaryDirectory() as temp_checkpoint_dir:
                torch.save(
                    model.state_dict(),
                    os.path.join(temp_checkpoint_dir, "model.pt")
                )
                train.report(
                    {"loss": loss.item(), "epoch": epoch},
                    checkpoint=Checkpoint.from_directory(temp_checkpoint_dir)
                )

# Configure distributed training
trainer = TorchTrainer(
    train_func,
    train_loop_config={
        "lr": 0.001,
        "num_epochs": 100
    },
    scaling_config=train.ScalingConfig(
        num_workers=4,  # Number of GPU workers
        use_gpu=True,
        resources_per_worker={"CPU": 2, "GPU": 1}
    ),
    torch_config=TorchConfig(backend="nccl"),  # Use NCCL for GPU communication
)

# Run training
result = trainer.fit()
print(f"Training completed: {result}")
```

Submit the training job:

```bash
# Copy training script to Ray cluster
kubectl cp distributed_training.py ray-training/ray-head-xxx:/tmp/

# Execute training job
kubectl exec -it -n ray-training ray-head-xxx -- python /tmp/distributed_training.py
```

## Option 2: PyTorch Distributed Training with Kubeflow

### Step 1: Install Kubeflow Training Operator

```bash
# Install Kubeflow Training Operator
kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.7.0"

# Verify installation
kubectl get pods -n kubeflow
```

### Step 2: Create PyTorchJob

```yaml
# pytorch-distributed-job.yaml
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: pytorch-distributed-training
  namespace: ray-training
spec:
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      restartPolicy: OnFailure
      template:
        metadata:
          annotations:
            sidecar.istio.io/inject: "false"
        spec:
          nodeSelector:
            node-class: gpu
          tolerations:
          - key: nvidia.com/gpu
            operator: Exists
            effect: NoSchedule
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime
            command:
            - python3
            - /opt/pytorch-dist/train.py
            - --backend=nccl
            - --epochs=100
            - --batch-size=64
            resources:
              limits:
                nvidia.com/gpu: 1
                memory: "16Gi"
                cpu: "4"
              requests:
                nvidia.com/gpu: 1
                memory: "8Gi"
                cpu: "2"
            volumeMounts:
            - name: training-code
              mountPath: /opt/pytorch-dist
            - name: dataset
              mountPath: /data
            - name: checkpoints
              mountPath: /checkpoints
          volumes:
          - name: training-code
            configMap:
              name: training-code
          - name: dataset
            persistentVolumeClaim:
              claimName: training-dataset
          - name: checkpoints
            persistentVolumeClaim:
              claimName: training-checkpoints
    
    Worker:
      replicas: 3
      restartPolicy: OnFailure
      template:
        metadata:
          annotations:
            sidecar.istio.io/inject: "false"
        spec:
          nodeSelector:
            node-class: gpu
          tolerations:
          - key: nvidia.com/gpu
            operator: Exists
            effect: NoSchedule
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime
            command:
            - python3
            - /opt/pytorch-dist/train.py
            - --backend=nccl
            - --epochs=100
            - --batch-size=64
            resources:
              limits:
                nvidia.com/gpu: 1
                memory: "16Gi"
                cpu: "4"
              requests:
                nvidia.com/gpu: 1
                memory: "8Gi"
                cpu: "2"
            volumeMounts:
            - name: training-code
              mountPath: /opt/pytorch-dist
            - name: dataset
              mountPath: /data
            - name: checkpoints
              mountPath: /checkpoints
          volumes:
          - name: training-code
            configMap:
              name: training-code
          - name: dataset
            persistentVolumeClaim:
              claimName: training-dataset
          - name: checkpoints
            persistentVolumeClaim:
              claimName: training-checkpoints
```

### Step 3: Create Training Script ConfigMap

```python
# Create training script
cat > train.py << 'EOF'
import argparse
import torch
import torch.nn as nn
import torch.distributed as dist
import torch.multiprocessing as mp
from torch.nn.parallel import DistributedDataParallel as DDP
import os

def setup(rank, world_size):
    """Initialize distributed training"""
    os.environ['MASTER_ADDR'] = os.environ.get('MASTER_ADDR', 'localhost')
    os.environ['MASTER_PORT'] = os.environ.get('MASTER_PORT', '12355')
    
    # Initialize process group
    dist.init_process_group("nccl", rank=rank, world_size=world_size)
    torch.cuda.set_device(rank)

def cleanup():
    """Clean up distributed training"""
    dist.destroy_process_group()

def train(rank, world_size, args):
    """Main training function"""
    setup(rank, world_size)
    
    # Create model
    model = nn.Sequential(
        nn.Linear(784, 512),
        nn.ReLU(),
        nn.Linear(512, 256),
        nn.ReLU(),
        nn.Linear(256, 10)
    ).cuda(rank)
    
    # Wrap model with DDP
    model = DDP(model, device_ids=[rank])
    
    # Create optimizer
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = nn.CrossEntropyLoss()
    
    # Training loop
    for epoch in range(args.epochs):
        # Simulate training data
        data = torch.randn(args.batch_size, 784).cuda(rank)
        target = torch.randint(0, 10, (args.batch_size,)).cuda(rank)
        
        optimizer.zero_grad()
        output = model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()
        
        if rank == 0 and epoch % 10 == 0:
            print(f'Epoch {epoch}, Loss: {loss.item():.4f}')
            
            # Save checkpoint
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'loss': loss.item(),
            }, f'/checkpoints/checkpoint_epoch_{epoch}.pt')
    
    cleanup()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--backend', type=str, default='nccl')
    parser.add_argument('--epochs', type=int, default=100)
    parser.add_argument('--batch-size', type=int, default=64)
    args = parser.parse_args()
    
    # Get distributed training info from environment
    rank = int(os.environ.get('RANK', 0))
    world_size = int(os.environ.get('WORLD_SIZE', 1))
    
    train(rank, world_size, args)
EOF
```

Create the ConfigMap:

```bash
# Create ConfigMap with training script
kubectl create configmap training-code \
  --from-file=train.py \
  -n ray-training
```

### Step 4: Create Storage Resources

```yaml
# storage-resources.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: training-dataset
  namespace: ray-training
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs
  resources:
    requests:
      storage: 1Ti
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: training-checkpoints
  namespace: ray-training
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3-fast
  resources:
    requests:
      storage: 100Gi
```

Apply the resources:

```bash
# Create storage resources
kubectl apply -f storage-resources.yaml

# Submit training job
kubectl apply -f pytorch-distributed-job.yaml

# Monitor training job
kubectl get pytorchjob -n ray-training
kubectl logs -n ray-training -l job-name=pytorch-distributed-training
```

## Data Pipeline Configuration

### Step 1: Set Up Data Loading

```python
# data_pipeline.py
import ray
from ray.data import Dataset
import torch
from torch.utils.data import DataLoader
import boto3
import os

@ray.remote
class DataProcessor:
    def __init__(self, s3_bucket, s3_prefix):
        self.s3_client = boto3.client('s3')
        self.bucket = s3_bucket
        self.prefix = s3_prefix
    
    def load_and_preprocess(self, file_key):
        """Load and preprocess a single file"""
        # Download file from S3
        local_path = f"/tmp/{os.path.basename(file_key)}"
        self.s3_client.download_file(self.bucket, file_key, local_path)
        
        # Load and preprocess data
        data = torch.load(local_path)
        
        # Apply preprocessing
        processed_data = self.preprocess(data)
        
        # Clean up
        os.remove(local_path)
        
        return processed_data
    
    def preprocess(self, data):
        """Apply preprocessing transformations"""
        # Normalize
        data = (data - data.mean()) / data.std()
        
        # Add noise for augmentation
        noise = torch.randn_like(data) * 0.01
        data = data + noise
        
        return data

def create_distributed_dataset(s3_bucket, s3_prefix, num_workers=4):
    """Create distributed dataset using Ray"""
    
    # List files in S3
    s3_client = boto3.client('s3')
    response = s3_client.list_objects_v2(Bucket=s3_bucket, Prefix=s3_prefix)
    file_keys = [obj['Key'] for obj in response.get('Contents', [])]
    
    # Create Ray dataset
    dataset = ray.data.from_items(file_keys)
    
    # Create data processors
    processors = [DataProcessor.remote(s3_bucket, s3_prefix) for _ in range(num_workers)]
    
    # Process data in parallel
    processed_dataset = dataset.map_batches(
        lambda batch: [ray.get(processors[i % num_workers].load_and_preprocess.remote(key)) 
                      for i, key in enumerate(batch)],
        batch_size=10,
        num_cpus=2
    )
    
    return processed_dataset

# Usage in training script
def get_data_loader(s3_bucket, s3_prefix, batch_size=32):
    """Get distributed data loader"""
    
    # Create distributed dataset
    dataset = create_distributed_dataset(s3_bucket, s3_prefix)
    
    # Convert to PyTorch DataLoader
    torch_dataset = dataset.to_torch(
        label_column="target",
        feature_columns=["features"],
        batch_size=batch_size
    )
    
    return torch_dataset
```

### Step 2: Configure Data Access

```yaml
# data-access-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: data-config
  namespace: ray-training
data:
  S3_BUCKET: "my-training-data-bucket"
  S3_PREFIX: "datasets/imagenet/"
  BATCH_SIZE: "64"
  NUM_WORKERS: "8"
---
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: ray-training
type: Opaque
data:
  AWS_ACCESS_KEY_ID: <base64-encoded-key>
  AWS_SECRET_ACCESS_KEY: <base64-encoded-secret>
```

## Experiment Tracking and Model Management

### Step 1: Deploy MLflow

```yaml
# mlflow-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow-server
  namespace: ray-training
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlflow-server
  template:
    metadata:
      labels:
        app: mlflow-server
    spec:
      containers:
      - name: mlflow
        image: python:3.9-slim
        command:
        - /bin/bash
        - -c
        - |
          pip install mlflow boto3 psycopg2-binary
          mlflow server \
            --backend-store-uri postgresql://mlflow:password@postgres:5432/mlflow \
            --default-artifact-root s3://my-mlflow-artifacts/ \
            --host 0.0.0.0 \
            --port 5000
        ports:
        - containerPort: 5000
        env:
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: AWS_ACCESS_KEY_ID
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: AWS_SECRET_ACCESS_KEY
---
apiVersion: v1
kind: Service
metadata:
  name: mlflow-service
  namespace: ray-training
spec:
  selector:
    app: mlflow-server
  ports:
  - port: 5000
    targetPort: 5000
  type: ClusterIP
```

### Step 2: Integrate MLflow with Training

```python
# mlflow_integration.py
import mlflow
import mlflow.pytorch
import torch
import os

def setup_mlflow():
    """Setup MLflow tracking"""
    mlflow.set_tracking_uri("http://mlflow-service:5000")
    mlflow.set_experiment("distributed-training")

def log_training_run(model, optimizer, config, metrics):
    """Log training run to MLflow"""
    
    with mlflow.start_run():
        # Log parameters
        mlflow.log_params(config)
        
        # Log metrics
        for epoch, metric_dict in enumerate(metrics):
            for metric_name, value in metric_dict.items():
                mlflow.log_metric(metric_name, value, step=epoch)
        
        # Log model
        mlflow.pytorch.log_model(
            model,
            "model",
            registered_model_name="distributed-model"
        )
        
        # Log artifacts
        mlflow.log_artifacts("/checkpoints", "checkpoints")
        
        return mlflow.active_run().info.run_id

# Modified training function with MLflow integration
def train_with_mlflow(rank, world_size, args):
    """Training function with MLflow logging"""
    
    if rank == 0:  # Only log from master process
        setup_mlflow()
    
    setup(rank, world_size)
    
    # Create model
    model = create_model().cuda(rank)
    model = DDP(model, device_ids=[rank])
    
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    
    metrics = []
    
    # Training loop
    for epoch in range(args.epochs):
        # Training step
        loss = training_step(model, optimizer, data_loader)
        
        # Collect metrics
        if rank == 0:
            epoch_metrics = {
                'loss': loss.item(),
                'learning_rate': optimizer.param_groups[0]['lr'],
                'epoch': epoch
            }
            metrics.append(epoch_metrics)
            
            # Log to MLflow every 10 epochs
            if epoch % 10 == 0:
                mlflow.log_metrics(epoch_metrics, step=epoch)
    
    # Final logging
    if rank == 0:
        run_id = log_training_run(
            model.module,  # Unwrap DDP model
            optimizer,
            vars(args),
            metrics
        )
        print(f"Training completed. MLflow run ID: {run_id}")
    
    cleanup()
```

## Resource Optimization for Training

### Step 1: GPU Memory Optimization

```python
# gpu_optimization.py
import torch
import torch.nn as nn
from torch.utils.checkpoint import checkpoint

class MemoryEfficientModel(nn.Module):
    def __init__(self, config):
        super().__init__()
        self.layers = nn.ModuleList([
            nn.Linear(config.hidden_size, config.hidden_size)
            for _ in range(config.num_layers)
        ])
        self.use_checkpointing = config.use_checkpointing
    
    def forward(self, x):
        for layer in self.layers:
            if self.use_checkpointing:
                # Use gradient checkpointing to save memory
                x = checkpoint(layer, x)
            else:
                x = layer(x)
        return x

def optimize_gpu_memory():
    """Apply GPU memory optimizations"""
    
    # Enable memory efficient attention
    torch.backends.cuda.enable_flash_sdp(True)
    
    # Set memory fraction
    torch.cuda.set_per_process_memory_fraction(0.9)
    
    # Enable memory pool
    os.environ['PYTORCH_CUDA_ALLOC_CONF'] = 'max_split_size_mb:128'
    
    # Clear cache periodically
    torch.cuda.empty_cache()

def mixed_precision_training(model, optimizer, data, target):
    """Training with mixed precision"""
    
    scaler = torch.cuda.amp.GradScaler()
    
    with torch.cuda.amp.autocast():
        output = model(data)
        loss = nn.CrossEntropyLoss()(output, target)
    
    scaler.scale(loss).backward()
    scaler.step(optimizer)
    scaler.update()
    
    return loss
```

### Step 2: Dynamic Resource Allocation

```yaml
# dynamic-training-job.yaml
apiVersion: ray.io/v1alpha1
kind: RayCluster
metadata:
  name: dynamic-training
spec:
  enableInTreeAutoscaling: true
  autoscalerOptions:
    upscalingMode: Default
    idleTimeoutSeconds: 60
    imagePullPolicy: Always
  
  headGroupSpec:
    replicas: 1
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.8.0-gpu
          env:
          - name: RAY_SCHEDULER_SPREAD_THRESHOLD
            value: "0.0"  # Aggressive spreading
  
  workerGroupSpecs:
  - replicas: 2
    minReplicas: 1
    maxReplicas: 20
    groupName: gpu-workers
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.8.0-gpu
          resources:
            limits:
              nvidia.com/gpu: 1
              memory: "32Gi"
            requests:
              nvidia.com/gpu: 1
              memory: "16Gi"
          env:
          - name: RAY_DISABLE_IMPORT_WARNING
            value: "1"
```

## Monitoring Training Jobs

### Step 1: Training Metrics Collection

```yaml
# training-monitoring.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: training-metrics-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'ray-cluster'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: ['ray-training']
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: ray-.*
    
    - job_name: 'gpu-metrics'
      static_configs:
      - targets: ['dcgm-exporter:9400']
    
    - job_name: 'training-metrics'
      static_configs:
      - targets: ['training-exporter:8000']
```

### Step 2: Custom Training Metrics

```python
# training_metrics.py
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import time
import threading

class TrainingMetrics:
    def __init__(self):
        # Counters
        self.training_steps = Counter('training_steps_total', 'Total training steps')
        self.training_epochs = Counter('training_epochs_total', 'Total training epochs')
        
        # Histograms
        self.step_duration = Histogram('training_step_duration_seconds', 'Training step duration')
        self.batch_size = Histogram('training_batch_size', 'Training batch size')
        
        # Gauges
        self.current_loss = Gauge('training_current_loss', 'Current training loss')
        self.learning_rate = Gauge('training_learning_rate', 'Current learning rate')
        self.gpu_memory_usage = Gauge('training_gpu_memory_bytes', 'GPU memory usage')
        
        # Start metrics server
        start_http_server(8000)
    
    def record_training_step(self, loss, lr, batch_size, step_time):
        """Record metrics for a training step"""
        self.training_steps.inc()
        self.current_loss.set(loss)
        self.learning_rate.set(lr)
        self.step_duration.observe(step_time)
        self.batch_size.observe(batch_size)
        
        # Record GPU memory usage
        if torch.cuda.is_available():
            memory_used = torch.cuda.memory_allocated()
            self.gpu_memory_usage.set(memory_used)
    
    def record_epoch_completion(self):
        """Record epoch completion"""
        self.training_epochs.inc()

# Usage in training loop
metrics = TrainingMetrics()

for epoch in range(num_epochs):
    for batch_idx, (data, target) in enumerate(train_loader):
        start_time = time.time()
        
        # Training step
        loss = training_step(model, optimizer, data, target)
        
        step_time = time.time() - start_time
        
        # Record metrics
        metrics.record_training_step(
            loss=loss.item(),
            lr=optimizer.param_groups[0]['lr'],
            batch_size=len(data),
            step_time=step_time
        )
    
    metrics.record_epoch_completion()
```

## Troubleshooting Training Issues

### Common Issues and Solutions

**Out of Memory Errors:**
```bash
# Check GPU memory usage
kubectl exec -n ray-training <pod-name> -- nvidia-smi

# Reduce batch size or enable gradient checkpointing
# Add to training script:
torch.cuda.empty_cache()
```

**Slow Training Performance:**
```bash
# Check data loading bottlenecks
kubectl top pods -n ray-training

# Monitor network I/O for distributed training
kubectl exec -n ray-training <pod-name> -- iftop
```

**Training Job Failures:**
```bash
# Check job status
kubectl describe pytorchjob pytorch-distributed-training -n ray-training

# Check logs from all workers
kubectl logs -n ray-training -l job-name=pytorch-distributed-training --tail=100
```

## Next Steps

- Configure [Storage](04-storage-configuration.md) for optimal data access
- Set up [Monitoring](07-monitoring-setup.md) for comprehensive observability
- Implement [CI/CD](08-cicd-setup.md) for automated training pipelines

## Repository References

This guide uses:
- **Ray Training**: [/blueprints/training/ray-train-gpu](../../blueprints/training/ray-train-gpu)
- **Distributed Training**: [/blueprints/training](../../blueprints/training)
- **MLflow Integration**: [/infra/mlflow](../../infra/mlflow)
