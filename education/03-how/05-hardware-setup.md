# GPU and Specialized Hardware Setup

This guide shows you how to configure GPU and specialized hardware (Trainium/Inferentia) for AI/ML workloads on EKS.

## Prerequisites

- EKS cluster set up (see [Cluster Setup](01-cluster-setup.md))
- kubectl configured to access your cluster
- AWS CLI with appropriate permissions
- Understanding of GPU and AI accelerator concepts

## Overview

We'll configure:
1. NVIDIA GPU support with device plugins
2. AWS Trainium for training workloads
3. AWS Inferentia for inference workloads
4. Hardware monitoring and resource allocation
5. Multi-GPU and distributed computing setup

## Option 1: NVIDIA GPU Setup

### Step 1: Create GPU Node Groups

First, create node groups with GPU instances:

```bash
# Create GPU node group using eksctl
eksctl create nodegroup \
  --cluster=ai-ml-cluster \
  --region=us-west-2 \
  --name=gpu-training \
  --node-type=p3.2xlarge \
  --nodes=2 \
  --nodes-min=0 \
  --nodes-max=10 \
  --node-ami-family=AmazonLinux2 \
  --ssh-access \
  --ssh-public-key=my-key \
  --managed=false \
  --node-labels="workload-type=training,node-class=gpu" \
  --node-taints="nvidia.com/gpu=true:NoSchedule"
```

Or using Terraform:

```hcl
# GPU node group configuration
resource "aws_eks_node_group" "gpu_training" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "gpu-training"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  
  instance_types = ["p3.2xlarge", "p3.8xlarge"]
  capacity_type  = "SPOT"  # Use spot for cost savings
  
  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 0
  }
  
  # GPU-optimized AMI
  ami_type = "AL2_x86_64_GPU"
  
  labels = {
    "workload-type" = "training"
    "node-class"    = "gpu"
  }
  
  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
  
  # User data for GPU setup
  user_data = base64encode(templatefile("${path.module}/gpu-userdata.sh", {
    cluster_name = aws_eks_cluster.main.name
  }))
  
  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Inference GPU node group
resource "aws_eks_node_group" "gpu_inference" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "gpu-inference"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  
  instance_types = ["g4dn.xlarge", "g4dn.2xlarge", "g5.xlarge"]
  capacity_type  = "ON_DEMAND"  # On-demand for production inference
  
  scaling_config {
    desired_size = 2
    max_size     = 20
    min_size     = 1
  }
  
  ami_type = "AL2_x86_64_GPU"
  
  labels = {
    "workload-type" = "inference"
    "node-class"    = "gpu"
  }
  
  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
}
```

### Step 2: Install NVIDIA Device Plugin

```bash
# Install NVIDIA device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml

# Verify installation
kubectl get pods -n kube-system | grep nvidia-device-plugin

# Check GPU resources are available
kubectl get nodes -o yaml | grep nvidia.com/gpu
```

### Step 3: Install GPU Operator (Alternative Approach)

For more comprehensive GPU management, use the NVIDIA GPU Operator:

```bash
# Add NVIDIA Helm repository
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

# Install GPU Operator
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=true \
  --set toolkit.enabled=true \
  --set devicePlugin.enabled=true \
  --set nodeStatusExporter.enabled=true \
  --set gfd.enabled=true \
  --set migManager.enabled=false \
  --set operator.defaultRuntime=containerd

# Verify installation
kubectl get pods -n gpu-operator
```

### Step 4: Configure GPU Monitoring

```yaml
# DCGM exporter for GPU metrics
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-dcgm-exporter
  namespace: gpu-operator
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
  template:
    metadata:
      labels:
        app: nvidia-dcgm-exporter
    spec:
      nodeSelector:
        node-class: gpu
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: nvidia-dcgm-exporter
        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.1.7-3.1.4-ubuntu20.04
        ports:
        - name: metrics
          containerPort: 9400
        securityContext:
          privileged: true
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        env:
        - name: DCGM_EXPORTER_LISTEN
          value: ":9400"
        - name: DCGM_EXPORTER_KUBERNETES
          value: "true"
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      hostNetwork: true
      hostPID: true
---
# Service for DCGM exporter
apiVersion: v1
kind: Service
metadata:
  name: nvidia-dcgm-exporter
  namespace: gpu-operator
  labels:
    app: nvidia-dcgm-exporter
spec:
  ports:
  - name: metrics
    port: 9400
    targetPort: 9400
  selector:
    app: nvidia-dcgm-exporter
---
# ServiceMonitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nvidia-dcgm-exporter
  namespace: gpu-operator
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## Option 2: AWS Trainium Setup

### Step 1: Create Trainium Node Groups

```hcl
# Trainium node group for training
resource "aws_eks_node_group" "trainium_training" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "trainium-training"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  
  instance_types = ["trn1.2xlarge", "trn1.32xlarge"]
  capacity_type  = "ON_DEMAND"
  
  scaling_config {
    desired_size = 1
    max_size     = 5
    min_size     = 0
  }
  
  # Use AL2 AMI (Neuron drivers will be installed via user data)
  ami_type = "AL2_x86_64"
  
  labels = {
    "workload-type" = "training"
    "node-class"    = "trainium"
    "accelerator"   = "neuron"
  }
  
  taint {
    key    = "aws.amazon.com/neuron"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
  
  # User data for Neuron setup
  user_data = base64encode(templatefile("${path.module}/trainium-userdata.sh", {
    cluster_name = aws_eks_cluster.main.name
  }))
}
```

### Step 2: Create Trainium User Data Script

```bash
# trainium-userdata.sh
#!/bin/bash

# Configure the kubelet
/etc/eks/bootstrap.sh ${cluster_name}

# Install Neuron driver and runtime
# Add Neuron repository
cat > /etc/yum.repos.d/neuron.repo << 'EOF'
[neuron]
name=Neuron YUM Repository
baseurl=https://yum.repos.neuron.amazonaws.com
enabled=1
metadata_expire=0
EOF

# Import Neuron GPG key
rpm --import https://yum.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-NEURON

# Install Neuron driver
yum install aws-neuronx-dkms -y
yum install aws-neuronx-oci-hook -y
yum install aws-neuronx-runtime-lib -y
yum install aws-neuronx-collectives -y

# Configure containerd for Neuron
cat >> /etc/containerd/config.toml << 'EOF'

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.neuron]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.neuron.options]
    BinaryName = "/usr/bin/neuron-runc"
EOF

# Restart containerd
systemctl restart containerd

# Load Neuron driver
modprobe neuron

# Verify Neuron installation
neuron-ls
```

### Step 3: Install Neuron Device Plugin

```yaml
# Neuron device plugin
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: neuron-device-plugin
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: neuron-device-plugin
  template:
    metadata:
      labels:
        name: neuron-device-plugin
    spec:
      nodeSelector:
        node-class: trainium
      tolerations:
      - key: aws.amazon.com/neuron
        operator: Exists
        effect: NoSchedule
      containers:
      - name: neuron-device-plugin
        image: public.ecr.aws/neuron/neuron-device-plugin:2.15.9.0
        securityContext:
          privileged: true
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
        - name: dev
          mountPath: /dev
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      - name: dev
        hostPath:
          path: /dev
      hostNetwork: true
```

### Step 4: Deploy Neuron Monitor

```yaml
# Neuron monitor for metrics collection
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: neuron-monitor
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: neuron-monitor
  template:
    metadata:
      labels:
        name: neuron-monitor
    spec:
      nodeSelector:
        node-class: trainium
      tolerations:
      - key: aws.amazon.com/neuron
        operator: Exists
        effect: NoSchedule
      containers:
      - name: neuron-monitor
        image: public.ecr.aws/neuron/neuron-monitor:2.15.9.0
        ports:
        - containerPort: 8000
          name: metrics
        securityContext:
          privileged: true
        volumeMounts:
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: proc
          mountPath: /host/proc
          readOnly: true
        env:
        - name: NEURON_MONITOR_PORT
          value: "8000"
      volumes:
      - name: sys
        hostPath:
          path: /sys
      - name: proc
        hostPath:
          path: /proc
      hostNetwork: true
---
# Service for Neuron monitor
apiVersion: v1
kind: Service
metadata:
  name: neuron-monitor
  namespace: kube-system
  labels:
    name: neuron-monitor
spec:
  ports:
  - name: metrics
    port: 8000
    targetPort: 8000
  selector:
    name: neuron-monitor
```

## Option 3: AWS Inferentia Setup

### Step 1: Create Inferentia Node Groups

```hcl
# Inferentia node group for inference
resource "aws_eks_node_group" "inferentia_inference" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "inferentia-inference"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  
  instance_types = ["inf2.xlarge", "inf2.8xlarge", "inf2.24xlarge"]
  capacity_type  = "ON_DEMAND"
  
  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 1
  }
  
  ami_type = "AL2_x86_64"
  
  labels = {
    "workload-type" = "inference"
    "node-class"    = "inferentia"
    "accelerator"   = "neuron"
  }
  
  taint {
    key    = "aws.amazon.com/neuron"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
  
  # User data for Neuron setup (similar to Trainium)
  user_data = base64encode(templatefile("${path.module}/inferentia-userdata.sh", {
    cluster_name = aws_eks_cluster.main.name
  }))
}
```

### Step 2: Test Hardware Setup

Create test workloads to verify hardware setup:

```yaml
# GPU test workload
apiVersion: batch/v1
kind: Job
metadata:
  name: gpu-test
  namespace: default
spec:
  template:
    spec:
      nodeSelector:
        node-class: gpu
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: gpu-test
        image: nvidia/cuda:11.8-runtime-ubuntu20.04
        command: ["nvidia-smi"]
        resources:
          limits:
            nvidia.com/gpu: 1
      restartPolicy: Never
---
# Trainium test workload
apiVersion: batch/v1
kind: Job
metadata:
  name: trainium-test
  namespace: default
spec:
  template:
    spec:
      nodeSelector:
        node-class: trainium
      tolerations:
      - key: aws.amazon.com/neuron
        operator: Exists
        effect: NoSchedule
      containers:
      - name: trainium-test
        image: public.ecr.aws/neuron/pytorch-training-neuronx:1.13.1-neuronx-py310-sdk2.15.0-ubuntu20.04
        command: ["neuron-ls"]
        resources:
          limits:
            aws.amazon.com/neuron: 1
      restartPolicy: Never
---
# Inferentia test workload
apiVersion: batch/v1
kind: Job
metadata:
  name: inferentia-test
  namespace: default
spec:
  template:
    spec:
      nodeSelector:
        node-class: inferentia
      tolerations:
      - key: aws.amazon.com/neuron
        operator: Exists
        effect: NoSchedule
      containers:
      - name: inferentia-test
        image: public.ecr.aws/neuron/pytorch-inference-neuronx:1.13.1-neuronx-py310-sdk2.15.0-ubuntu20.04
        command: ["neuron-ls"]
        resources:
          limits:
            aws.amazon.com/neuron: 1
      restartPolicy: Never
```

Run the tests:

```bash
# Apply test jobs
kubectl apply -f hardware-tests.yaml

# Check GPU test
kubectl logs job/gpu-test

# Check Trainium test
kubectl logs job/trainium-test

# Check Inferentia test
kubectl logs job/inferentia-test

# Clean up tests
kubectl delete job gpu-test trainium-test inferentia-test
```

## Multi-GPU Configuration

### Step 1: Multi-GPU Training Setup

```yaml
# Multi-GPU training deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-gpu-training
  namespace: ml-training
spec:
  replicas: 1
  selector:
    matchLabels:
      app: multi-gpu-training
  template:
    metadata:
      labels:
        app: multi-gpu-training
    spec:
      nodeSelector:
        node-class: gpu
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: training
        image: pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime
        command:
        - python
        - -m
        - torch.distributed.launch
        - --nproc_per_node=4
        - train.py
        resources:
          limits:
            nvidia.com/gpu: 4  # Request 4 GPUs
            memory: "64Gi"
            cpu: "16"
          requests:
            nvidia.com/gpu: 4
            memory: "32Gi"
            cpu: "8"
        env:
        - name: CUDA_VISIBLE_DEVICES
          value: "0,1,2,3"
        - name: NCCL_DEBUG
          value: "INFO"
        volumeMounts:
        - name: training-data
          mountPath: /data
        - name: model-output
          mountPath: /output
      volumes:
      - name: training-data
        persistentVolumeClaim:
          claimName: training-data-pvc
      - name: model-output
        persistentVolumeClaim:
          claimName: model-output-pvc
```

### Step 2: GPU Sharing Configuration

For inference workloads that don't need full GPU resources:

```yaml
# GPU sharing with time-slicing
apiVersion: v1
kind: ConfigMap
metadata:
  name: gpu-sharing-config
  namespace: gpu-operator
data:
  config.yaml: |
    version: v1
    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: 4  # Share each GPU among 4 pods
---
# Apply GPU sharing configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-policy-config
  namespace: gpu-operator
data:
  config.yaml: |
    version: v1
    devicePlugin:
      config:
        name: gpu-sharing-config
        default: "gpu-sharing-config"
```

## Hardware Performance Optimization

### Step 1: GPU Performance Tuning

```bash
# GPU performance optimization script
#!/bin/bash

# Set GPU performance mode
nvidia-smi -pm 1

# Set maximum GPU clocks
nvidia-smi -ac 877,1530  # Memory,Graphics clocks for V100

# Enable persistence mode
nvidia-smi -pm 1

# Set power limit (if needed)
nvidia-smi -pl 300  # 300W for V100

# Verify settings
nvidia-smi -q -d PERFORMANCE
```

### Step 2: Memory Optimization

```python
# GPU memory optimization for PyTorch
import torch
import os

def optimize_gpu_memory():
    """Optimize GPU memory usage"""
    
    # Set memory fraction
    torch.cuda.set_per_process_memory_fraction(0.9)
    
    # Enable memory efficient attention
    torch.backends.cuda.enable_flash_sdp(True)
    
    # Configure memory allocator
    os.environ['PYTORCH_CUDA_ALLOC_CONF'] = 'max_split_size_mb:128'
    
    # Clear cache periodically
    torch.cuda.empty_cache()
    
    # Use gradient checkpointing for large models
    torch.utils.checkpoint.checkpoint_sequential

def monitor_gpu_memory():
    """Monitor GPU memory usage"""
    if torch.cuda.is_available():
        for i in range(torch.cuda.device_count()):
            memory_allocated = torch.cuda.memory_allocated(i)
            memory_reserved = torch.cuda.memory_reserved(i)
            memory_total = torch.cuda.get_device_properties(i).total_memory
            
            print(f"GPU {i}:")
            print(f"  Allocated: {memory_allocated / 1024**3:.2f} GB")
            print(f"  Reserved: {memory_reserved / 1024**3:.2f} GB")
            print(f"  Total: {memory_total / 1024**3:.2f} GB")
            print(f"  Utilization: {memory_allocated / memory_total * 100:.1f}%")
```

## Hardware Monitoring Dashboard

### Step 1: Create Grafana Dashboard

```json
{
  "dashboard": {
    "title": "AI Hardware Monitoring",
    "panels": [
      {
        "title": "GPU Utilization",
        "type": "graph",
        "targets": [
          {
            "expr": "DCGM_FI_DEV_GPU_UTIL",
            "legendFormat": "GPU {{gpu}} - {{instance}}"
          }
        ]
      },
      {
        "title": "GPU Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "DCGM_FI_DEV_MEM_COPY_UTIL",
            "legendFormat": "GPU {{gpu}} Memory"
          }
        ]
      },
      {
        "title": "GPU Temperature",
        "type": "graph",
        "targets": [
          {
            "expr": "DCGM_FI_DEV_GPU_TEMP",
            "legendFormat": "GPU {{gpu}} Temp"
          }
        ]
      },
      {
        "title": "Neuron Core Utilization",
        "type": "graph",
        "targets": [
          {
            "expr": "neuron_core_utilization",
            "legendFormat": "Neuron Core {{core}}"
          }
        ]
      }
    ]
  }
}
```

## Troubleshooting Hardware Issues

### Common GPU Issues

**GPU not detected:**
```bash
# Check GPU visibility
kubectl exec -it <pod-name> -- nvidia-smi

# Check device plugin logs
kubectl logs -n kube-system -l name=nvidia-device-plugin

# Verify node labels
kubectl get nodes -l node-class=gpu -o yaml
```

**Out of GPU memory:**
```bash
# Check GPU memory usage
kubectl exec -it <pod-name> -- nvidia-smi

# Check resource requests vs limits
kubectl describe pod <pod-name>

# Monitor GPU metrics
kubectl port-forward -n gpu-operator svc/nvidia-dcgm-exporter 9400:9400
curl http://localhost:9400/metrics | grep DCGM_FI_DEV_MEM
```

### Common Neuron Issues

**Neuron devices not available:**
```bash
# Check Neuron device plugin
kubectl logs -n kube-system -l name=neuron-device-plugin

# Verify Neuron installation on node
kubectl exec -it <pod-name> -- neuron-ls

# Check node resources
kubectl describe node <node-name> | grep aws.amazon.com/neuron
```

## Next Steps

- Configure [Networking and Security](06-networking-security.md) for hardware-specific security
- Set up [Monitoring](07-monitoring-setup.md) for comprehensive hardware observability
- Implement [Scaling](09-scaling-optimization.md) for hardware-aware autoscaling

## Repository References

This guide uses:
- **GPU Infrastructure**: [/infra/base/terraform](../../infra/base/terraform)
- **Hardware Examples**: [/blueprints/training](../../blueprints/training) and [/blueprints/inference](../../blueprints/inference)
- **Monitoring Setup**: [/infra/base/kubernetes-addons](../../infra/base/kubernetes-addons)
