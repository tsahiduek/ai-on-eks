# Exercise 2: Set Up Distributed Training 🟡

**Objective**: Set up and run distributed training using Ray on multiple GPUs, configure data loading and checkpointing, and monitor training progress.

**Difficulty**: Intermediate  
**Estimated Time**: 2-3 hours  
**Prerequisites**: Completed Exercise 1, EKS cluster with multiple GPU nodes

## What You'll Learn

- How to set up Ray clusters for distributed training
- Configure multi-GPU training with PyTorch
- Implement efficient data loading and checkpointing
- Monitor distributed training progress
- Handle fault tolerance and recovery
- Optimize training performance across multiple nodes

## Prerequisites

- EKS cluster with at least 2 GPU nodes (g4dn.xlarge or better)
- Completed [Exercise 1: Deploy Your First LLM](01-deploy-first-llm.md)
- kubectl configured to access your cluster
- Basic understanding of distributed training concepts

## Step 1: Set Up Ray Training Cluster

First, let's deploy a Ray cluster optimized for distributed training:

```bash
# Create namespace for training
kubectl create namespace distributed-training

# Navigate to Ray training blueprint
cd blueprints/training/ray-train-gpu
```

Create a custom configuration for distributed training:

```yaml
# distributed-ray-values.yaml
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
    num-cpus: '0'  # Don't schedule training work on head node
    dashboard-port: '8265'

worker:
  # GPU workers for training
  - groupName: gpu-workers
    replicas: 4  # Start with 4 workers
    minReplicas: 2
    maxReplicas: 8
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
      num-cpus: '8'
    nodeSelector:
      node-class: gpu
    tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule

# Storage for datasets and checkpoints
storage:
  datasets:
    enabled: true
    storageClass: "efs"
    size: "500Gi"
    accessMode: ReadWriteMany
  checkpoints:
    enabled: true
    storageClass: "gp3-fast"
    size: "100Gi"
    accessMode: ReadWriteOnce

# Monitoring
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
```

Deploy the Ray cluster:

```bash
# Deploy Ray cluster
helm install ray-training . \
  --namespace distributed-training \
  --values distributed-ray-values.yaml

# Wait for cluster to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ray-cluster -n distributed-training --timeout=300s

# Verify cluster status
kubectl get pods -n distributed-training
kubectl get raycluster -n distributed-training
```

## Step 2: Access Ray Dashboard

Set up port forwarding to access the Ray dashboard:

```bash
# Port forward Ray dashboard
kubectl port-forward -n distributed-training svc/ray-training-head-svc 8265:8265 &

# Access dashboard at http://localhost:8265
echo "Ray Dashboard available at: http://localhost:8265"
```

## Step 3: Create Distributed Training Script

Create a comprehensive distributed training script:

```python
# distributed_training_exercise.py
import ray
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
from ray import train
from ray.train import Checkpoint, ScalingConfig
from ray.train.torch import TorchTrainer, TorchConfig
import numpy as np
import tempfile
import os
import time
import json
from datetime import datetime

# Custom dataset for demonstration
class SyntheticDataset(Dataset):
    def __init__(self, size=10000, input_dim=784, num_classes=10):
        self.size = size
        self.input_dim = input_dim
        self.num_classes = num_classes
        
        # Generate synthetic data
        torch.manual_seed(42)
        self.data = torch.randn(size, input_dim)
        self.targets = torch.randint(0, num_classes, (size,))
    
    def __len__(self):
        return self.size
    
    def __getitem__(self, idx):
        return self.data[idx], self.targets[idx]

# Neural network model
class DistributedModel(nn.Module):
    def __init__(self, input_dim=784, hidden_dim=512, num_classes=10):
        super().__init__()
        self.fc1 = nn.Linear(input_dim, hidden_dim)
        self.fc2 = nn.Linear(hidden_dim, hidden_dim)
        self.fc3 = nn.Linear(hidden_dim, num_classes)
        self.dropout = nn.Dropout(0.2)
        
    def forward(self, x):
        x = F.relu(self.fc1(x))
        x = self.dropout(x)
        x = F.relu(self.fc2(x))
        x = self.dropout(x)
        x = self.fc3(x)
        return x

def train_func(config):
    """Training function that runs on each worker"""
    
    # Get distributed training context
    rank = train.get_context().get_world_rank()
    world_size = train.get_context().get_world_size()
    local_rank = train.get_context().get_local_rank()
    
    print(f"Worker {rank}/{world_size} (local rank {local_rank}) starting training")
    
    # Set device
    device = torch.device(f"cuda:{local_rank}" if torch.cuda.is_available() else "cpu")
    torch.cuda.set_device(local_rank)
    
    # Create model
    model = DistributedModel(
        input_dim=config["input_dim"],
        hidden_dim=config["hidden_dim"],
        num_classes=config["num_classes"]
    ).to(device)
    
    # Wrap model for distributed training
    model = torch.nn.parallel.DistributedDataParallel(
        model, 
        device_ids=[local_rank],
        output_device=local_rank
    )
    
    # Create dataset and dataloader
    dataset = SyntheticDataset(
        size=config["dataset_size"],
        input_dim=config["input_dim"],
        num_classes=config["num_classes"]
    )
    
    # Create distributed sampler
    sampler = torch.utils.data.distributed.DistributedSampler(
        dataset,
        num_replicas=world_size,
        rank=rank,
        shuffle=True
    )
    
    dataloader = DataLoader(
        dataset,
        batch_size=config["batch_size"],
        sampler=sampler,
        num_workers=2,
        pin_memory=True
    )
    
    # Create optimizer and scheduler
    optimizer = torch.optim.Adam(model.parameters(), lr=config["lr"])
    scheduler = torch.optim.lr_scheduler.StepLR(
        optimizer, 
        step_size=config["scheduler_step"], 
        gamma=config["scheduler_gamma"]
    )
    
    criterion = nn.CrossEntropyLoss()
    
    # Training metrics
    training_metrics = {
        'epoch_losses': [],
        'epoch_accuracies': [],
        'learning_rates': [],
        'training_times': []
    }
    
    # Training loop
    for epoch in range(config["num_epochs"]):
        epoch_start_time = time.time()
        
        # Set epoch for distributed sampler
        sampler.set_epoch(epoch)
        
        model.train()
        epoch_loss = 0.0
        correct_predictions = 0
        total_samples = 0
        
        for batch_idx, (data, target) in enumerate(dataloader):
            data, target = data.to(device), target.to(device)
            
            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            
            # Calculate accuracy
            pred = output.argmax(dim=1, keepdim=True)
            correct_predictions += pred.eq(target.view_as(pred)).sum().item()
            total_samples += target.size(0)
            epoch_loss += loss.item()
            
            # Log progress every 50 batches
            if batch_idx % 50 == 0 and rank == 0:
                print(f'Epoch {epoch}, Batch {batch_idx}, Loss: {loss.item():.4f}')
        
        # Calculate epoch metrics
        avg_loss = epoch_loss / len(dataloader)
        accuracy = 100.0 * correct_predictions / total_samples
        current_lr = optimizer.param_groups[0]['lr']
        epoch_time = time.time() - epoch_start_time
        
        # Update scheduler
        scheduler.step()
        
        # Store metrics
        training_metrics['epoch_losses'].append(avg_loss)
        training_metrics['epoch_accuracies'].append(accuracy)
        training_metrics['learning_rates'].append(current_lr)
        training_metrics['training_times'].append(epoch_time)
        
        # Report metrics to Ray Train
        metrics_to_report = {
            "loss": avg_loss,
            "accuracy": accuracy,
            "learning_rate": current_lr,
            "epoch_time": epoch_time,
            "epoch": epoch
        }
        
        # Save checkpoint every 5 epochs
        if epoch % 5 == 0:
            with tempfile.TemporaryDirectory() as temp_checkpoint_dir:
                # Save model state
                checkpoint_path = os.path.join(temp_checkpoint_dir, "model.pt")
                torch.save({
                    'epoch': epoch,
                    'model_state_dict': model.module.state_dict(),
                    'optimizer_state_dict': optimizer.state_dict(),
                    'scheduler_state_dict': scheduler.state_dict(),
                    'loss': avg_loss,
                    'accuracy': accuracy,
                    'training_metrics': training_metrics
                }, checkpoint_path)
                
                # Save training metrics
                metrics_path = os.path.join(temp_checkpoint_dir, "metrics.json")
                with open(metrics_path, 'w') as f:
                    json.dump(training_metrics, f, indent=2)
                
                # Report with checkpoint
                train.report(
                    metrics_to_report,
                    checkpoint=Checkpoint.from_directory(temp_checkpoint_dir)
                )
        else:
            # Report without checkpoint
            train.report(metrics_to_report)
        
        if rank == 0:
            print(f'Epoch {epoch}: Loss={avg_loss:.4f}, Accuracy={accuracy:.2f}%, LR={current_lr:.6f}, Time={epoch_time:.2f}s')
    
    print(f"Worker {rank} completed training")

# Training configuration
training_config = {
    "input_dim": 784,
    "hidden_dim": 512,
    "num_classes": 10,
    "dataset_size": 50000,
    "batch_size": 128,
    "num_epochs": 50,
    "lr": 0.001,
    "scheduler_step": 15,
    "scheduler_gamma": 0.5
}

# Configure distributed training
def run_distributed_training():
    """Run distributed training with Ray"""
    
    # Initialize Ray if not already initialized
    if not ray.is_initialized():
        ray.init(address="ray://ray-training-head-svc:10001")
    
    # Configure trainer
    trainer = TorchTrainer(
        train_func,
        train_loop_config=training_config,
        scaling_config=ScalingConfig(
            num_workers=4,  # Number of GPU workers
            use_gpu=True,
            resources_per_worker={"CPU": 2, "GPU": 1}
        ),
        torch_config=TorchConfig(
            backend="nccl",  # Use NCCL for GPU communication
            init_method="env://"
        ),
    )
    
    # Run training
    print("Starting distributed training...")
    start_time = time.time()
    
    result = trainer.fit()
    
    end_time = time.time()
    total_time = end_time - start_time
    
    print(f"\nTraining completed in {total_time:.2f} seconds")
    print(f"Final metrics: {result.metrics}")
    
    # Get the best checkpoint
    if result.checkpoint:
        print(f"Best checkpoint saved at: {result.checkpoint}")
        
        # Load and inspect the checkpoint
        checkpoint_data = result.checkpoint.to_dict()
        print(f"Checkpoint contains: {list(checkpoint_data.keys())}")
    
    return result

if __name__ == "__main__":
    result = run_distributed_training()
```

## Step 4: Run the Training Job

Create a Kubernetes job to run the distributed training:

```yaml
# distributed-training-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: distributed-training-job
  namespace: distributed-training
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: training-runner
        image: rayproject/ray-ml:2.8.0-gpu
        command: ["python", "/app/distributed_training_exercise.py"]
        env:
        - name: RAY_ADDRESS
          value: "ray://ray-training-head-svc:10001"
        volumeMounts:
        - name: training-script
          mountPath: /app
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
          requests:
            cpu: "1"
            memory: "2Gi"
      volumes:
      - name: training-script
        configMap:
          name: training-script
```

Create the ConfigMap and run the job:

```bash
# Create ConfigMap with training script
kubectl create configmap training-script \
  --from-file=distributed_training_exercise.py \
  -n distributed-training

# Submit training job
kubectl apply -f distributed-training-job.yaml

# Monitor job progress
kubectl logs -f job/distributed-training-job -n distributed-training
```

## Step 5: Monitor Training Progress

### Monitor via Ray Dashboard

1. Access the Ray dashboard at http://localhost:8265
2. Navigate to the "Jobs" tab to see your training job
3. Click on the job to see detailed metrics and logs
4. Monitor resource utilization across workers

### Monitor via Kubernetes

```bash
# Check job status
kubectl get jobs -n distributed-training

# Check pod status
kubectl get pods -n distributed-training

# Monitor resource usage
kubectl top pods -n distributed-training

# Check GPU utilization
kubectl exec -n distributed-training <ray-worker-pod> -- nvidia-smi
```

### Custom Monitoring Script

Create a monitoring script to track training progress:

```python
# monitor_training.py
import ray
import time
import matplotlib.pyplot as plt
from ray.train import get_checkpoint
import json

def monitor_training_progress():
    """Monitor and visualize training progress"""
    
    # Connect to Ray cluster
    ray.init(address="ray://localhost:10001")
    
    metrics_history = []
    
    try:
        while True:
            # Get current job status
            jobs = ray.list_jobs()
            
            for job in jobs:
                if job.status == "RUNNING":
                    print(f"Job {job.job_id} is running...")
                    
                    # Try to get latest checkpoint
                    try:
                        # This would be implemented based on your specific setup
                        # For now, we'll simulate monitoring
                        print("Training in progress...")
                    except Exception as e:
                        print(f"Could not retrieve metrics: {e}")
            
            time.sleep(30)  # Check every 30 seconds
            
    except KeyboardInterrupt:
        print("Monitoring stopped")
    finally:
        ray.shutdown()

if __name__ == "__main__":
    monitor_training_progress()
```

## Step 6: Implement Fault Tolerance

Add fault tolerance to handle worker failures:

```python
# fault_tolerant_training.py
import ray
from ray import train
from ray.train.torch import TorchTrainer
from ray.train import RunConfig, CheckpointConfig
from ray.train.torch import TorchConfig

def create_fault_tolerant_trainer():
    """Create trainer with fault tolerance configuration"""
    
    trainer = TorchTrainer(
        train_func,
        train_loop_config=training_config,
        scaling_config=ScalingConfig(
            num_workers=4,
            use_gpu=True,
            resources_per_worker={"CPU": 2, "GPU": 1}
        ),
        torch_config=TorchConfig(
            backend="nccl",
            init_method="env://"
        ),
        run_config=RunConfig(
            # Checkpoint configuration
            checkpoint_config=CheckpointConfig(
                num_to_keep=3,  # Keep last 3 checkpoints
                checkpoint_score_attribute="accuracy",
                checkpoint_score_order="max"
            ),
            # Failure handling
            failure_config=ray.train.FailureConfig(
                max_failures=3,  # Allow up to 3 failures
                fail_fast=False
            ),
            # Progress reporting
            progress_reporter=ray.train.CLIReporter(
                metric_columns=["loss", "accuracy", "learning_rate"],
                max_report_frequency=30
            )
        )
    )
    
    return trainer

# Enhanced training function with checkpointing
def fault_tolerant_train_func(config):
    """Training function with fault tolerance"""
    
    rank = train.get_context().get_world_rank()
    
    # Try to restore from checkpoint
    checkpoint = train.get_checkpoint()
    start_epoch = 0
    
    if checkpoint:
        print(f"Worker {rank}: Restoring from checkpoint")
        checkpoint_data = checkpoint.to_dict()
        
        # Load model state
        model_state = torch.load(checkpoint_data["model.pt"])
        start_epoch = model_state['epoch'] + 1
        
        print(f"Worker {rank}: Resuming from epoch {start_epoch}")
    
    # Initialize model, optimizer, etc.
    model = create_model()
    optimizer = create_optimizer(model)
    
    if checkpoint:
        model.load_state_dict(model_state['model_state_dict'])
        optimizer.load_state_dict(model_state['optimizer_state_dict'])
    
    # Training loop starting from start_epoch
    for epoch in range(start_epoch, config["num_epochs"]):
        # Training logic here
        loss, accuracy = train_epoch(model, optimizer, epoch)
        
        # Save checkpoint every 5 epochs
        if epoch % 5 == 0:
            save_checkpoint(model, optimizer, epoch, loss, accuracy)
        
        # Report progress
        train.report({
            "loss": loss,
            "accuracy": accuracy,
            "epoch": epoch
        })
```

## Step 7: Performance Optimization

### Optimize Data Loading

```python
# optimized_data_loading.py
import torch
from torch.utils.data import DataLoader
import ray

@ray.remote
class DataWorker:
    def __init__(self, data_path):
        self.data_path = data_path
        # Initialize data loading logic
    
    def load_batch(self, batch_indices):
        # Load and preprocess batch
        return processed_batch

def create_optimized_dataloader(dataset, batch_size, num_workers=4):
    """Create optimized dataloader with Ray"""
    
    # Create Ray data workers
    data_workers = [DataWorker.remote(f"data_shard_{i}") 
                   for i in range(num_workers)]
    
    # Custom collate function for Ray data
    def ray_collate_fn(batch):
        # Process batch with Ray workers
        futures = [worker.load_batch.remote(batch) 
                  for worker in data_workers]
        results = ray.get(futures)
        return torch.stack(results)
    
    return DataLoader(
        dataset,
        batch_size=batch_size,
        num_workers=num_workers,
        pin_memory=True,
        persistent_workers=True,
        collate_fn=ray_collate_fn
    )
```

### GPU Memory Optimization

```python
# gpu_memory_optimization.py
import torch
import torch.nn as nn

def optimize_gpu_memory():
    """Apply GPU memory optimizations"""
    
    # Set memory fraction to avoid OOM
    if torch.cuda.is_available():
        torch.cuda.set_per_process_memory_fraction(0.8)
    
    # Enable memory efficient attention
    torch.backends.cuda.enable_flash_sdp(True)
    
    # Configure memory allocator
    os.environ['PYTORCH_CUDA_ALLOC_CONF'] = 'max_split_size_mb:128'

def mixed_precision_training_step(model, optimizer, data, target, scaler):
    """Training step with mixed precision"""
    
    with torch.cuda.amp.autocast():
        output = model(data)
        loss = F.cross_entropy(output, target)
    
    scaler.scale(loss).backward()
    scaler.step(optimizer)
    scaler.update()
    
    return loss

# Use gradient checkpointing for large models
class CheckpointedModel(nn.Module):
    def __init__(self, base_model):
        super().__init__()
        self.base_model = base_model
    
    def forward(self, x):
        return torch.utils.checkpoint.checkpoint(self.base_model, x)
```

## Verification Checklist

Verify your distributed training setup:

- [ ] Ray cluster is running with multiple GPU workers
- [ ] Training job successfully starts on all workers
- [ ] Model synchronization works across workers
- [ ] Checkpointing and recovery work correctly
- [ ] Training metrics are being collected and reported
- [ ] GPU utilization is high across all workers
- [ ] Training completes successfully

## Challenge Tasks 🔴

### Challenge 1: Implement Advanced Fault Tolerance
Add sophisticated fault tolerance that can handle:
1. Worker node failures during training
2. Automatic worker replacement
3. Dynamic scaling based on available resources
4. Graceful degradation when resources are limited

### Challenge 2: Multi-Node Training Optimization
Optimize training for multi-node scenarios:
1. Implement gradient compression
2. Add communication optimization (gradient accumulation)
3. Implement hierarchical all-reduce
4. Measure and optimize communication overhead

### Challenge 3: Advanced Monitoring and Profiling
Set up comprehensive monitoring:
1. GPU utilization and memory usage per worker
2. Network bandwidth utilization between nodes
3. Training throughput (samples/second)
4. Automatic performance regression detection

### Challenge 4: Hyperparameter Optimization at Scale
Implement distributed hyperparameter tuning:
1. Use Ray Tune for parallel hyperparameter search
2. Implement early stopping based on performance
3. Add population-based training
4. Optimize resource allocation for different trials

## Troubleshooting

### Common Issues

**Workers not connecting:**
```bash
# Check Ray cluster status
kubectl exec -n distributed-training ray-training-head-xxx -- ray status

# Check network connectivity
kubectl exec -n distributed-training ray-training-worker-xxx -- ping ray-training-head-svc
```

**NCCL communication errors:**
```bash
# Check GPU topology
kubectl exec -n distributed-training <worker-pod> -- nvidia-smi topo -m

# Verify NCCL environment
kubectl exec -n distributed-training <worker-pod> -- env | grep NCCL
```

**Out of memory errors:**
```bash
# Check GPU memory usage
kubectl exec -n distributed-training <worker-pod> -- nvidia-smi

# Reduce batch size or enable gradient checkpointing
# Monitor memory usage during training
```

**Slow training performance:**
```bash
# Check data loading bottlenecks
kubectl top pods -n distributed-training

# Monitor network I/O
kubectl exec -n distributed-training <worker-pod> -- iftop

# Check for CPU bottlenecks
kubectl exec -n distributed-training <worker-pod> -- htop
```

## Clean Up

When you're done with the exercise:

```bash
# Stop port forwarding
pkill -f "kubectl port-forward"

# Delete training job
kubectl delete job distributed-training-job -n distributed-training

# Delete Ray cluster
helm uninstall ray-training -n distributed-training

# Delete namespace
kubectl delete namespace distributed-training
```

## Next Steps

Congratulations! You've successfully set up distributed training on EKS. Next, try:

1. **[Exercise 3: Multi-Model Serving Platform](03-multi-model-serving.md)** - Deploy multiple models efficiently
2. **[Exercise 5: Production Monitoring Setup](05-production-monitoring.md)** - Set up comprehensive monitoring
3. **[Exercise 8: Advanced Scaling Scenarios](08-advanced-scaling.md)** - Implement advanced scaling strategies

## Key Takeaways

- Ray provides excellent distributed training capabilities on Kubernetes
- Proper fault tolerance is crucial for long-running training jobs
- GPU memory optimization is essential for large models
- Monitoring and observability help identify bottlenecks
- Data loading can be a significant bottleneck in distributed training
- Communication overhead increases with the number of workers

## Share Your Results

Share your experience with the community:
- Post your training performance benchmarks
- Share optimization techniques you discovered
- Contribute improvements to the training blueprints
- Help others troubleshoot distributed training issues
