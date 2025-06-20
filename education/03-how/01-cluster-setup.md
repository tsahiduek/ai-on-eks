# Setting Up Your AI/ML EKS Cluster

This guide walks you through setting up a production-ready EKS cluster optimized for AI/ML workloads using the infrastructure components from this repository.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl >= 1.21
- Helm >= 3.0
- Git access to this repository

## Overview

We'll set up:
1. VPC and networking infrastructure
2. EKS cluster with AI/ML optimized configuration
3. Node groups for different workload types
4. Essential add-ons and operators
5. Storage classes and configurations

## Step 1: Clone and Prepare the Repository

```bash
# Clone the repository
git clone https://github.com/awslabs/ai-on-eks.git
cd ai-on-eks

# Navigate to the base infrastructure
cd infra/base/terraform
```

## Step 2: Configure Your Environment

Create a `terraform.tfvars` file with your specific configuration:

```hcl
# terraform.tfvars
cluster_name = "ai-ml-cluster"
region       = "us-west-2"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
azs      = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Node Groups Configuration
node_groups = {
  # CPU workloads
  cpu_nodes = {
    instance_types = ["m5.large", "m5.xlarge"]
    capacity_type  = "SPOT"
    min_size      = 1
    max_size      = 10
    desired_size  = 2
    
    labels = {
      workload-type = "cpu"
      node-class    = "general"
    }
  }
  
  # GPU training nodes
  gpu_training = {
    instance_types = ["p3.2xlarge", "p3.8xlarge"]
    capacity_type  = "SPOT"
    min_size      = 0
    max_size      = 5
    desired_size  = 0
    
    labels = {
      workload-type = "training"
      node-class    = "gpu"
    }
    
    taints = [{
      key    = "nvidia.com/gpu"
      value  = "true"
      effect = "NO_SCHEDULE"
    }]
  }
  
  # GPU inference nodes
  gpu_inference = {
    instance_types = ["g4dn.xlarge", "g4dn.2xlarge"]
    capacity_type  = "ON_DEMAND"
    min_size      = 1
    max_size      = 10
    desired_size  = 2
    
    labels = {
      workload-type = "inference"
      node-class    = "gpu"
    }
    
    taints = [{
      key    = "nvidia.com/gpu"
      value  = "true"
      effect = "NO_SCHEDULE"
    }]
  }
}

# Add-ons to install
enable_aws_load_balancer_controller = true
enable_cluster_autoscaler          = true
enable_nvidia_device_plugin        = true
enable_prometheus                  = true
enable_grafana                     = true

# Tags
tags = {
  Environment = "production"
  Project     = "ai-ml-platform"
  Owner       = "platform-team"
}
```

## Step 3: Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file="terraform.tfvars"

# Apply the configuration
terraform apply -var-file="terraform.tfvars"
```

This will create:
- VPC with public and private subnets across 3 AZs
- EKS cluster with managed node groups
- IAM roles and policies
- Security groups optimized for AI/ML workloads

## Step 4: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name ai-ml-cluster

# Verify cluster access
kubectl get nodes
kubectl get pods -A
```

## Step 5: Install Essential Add-ons

The Terraform configuration includes essential add-ons, but let's verify and configure them:

### NVIDIA Device Plugin

```bash
# Verify NVIDIA device plugin is running
kubectl get pods -n kube-system | grep nvidia

# Check GPU resources are available
kubectl describe nodes | grep nvidia.com/gpu
```

### Cluster Autoscaler

```bash
# Verify cluster autoscaler is running
kubectl get deployment cluster-autoscaler -n kube-system

# Check logs
kubectl logs -n kube-system deployment/cluster-autoscaler
```

### AWS Load Balancer Controller

```bash
# Verify AWS Load Balancer Controller
kubectl get deployment aws-load-balancer-controller -n kube-system

# Check webhook is ready
kubectl get validatingwebhookconfigurations | grep aws-load-balancer
```

## Step 6: Configure Storage Classes

Create storage classes optimized for AI/ML workloads:

```yaml
# storage-classes.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-fast
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-training
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "16000"
  throughput: "1000"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
# FSx for Lustre storage class (for high-performance training)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fsx-lustre
provisioner: fsx.csi.aws.com
parameters:
  subnetId: subnet-12345678  # Replace with your subnet ID
  securityGroupIds: sg-12345678  # Replace with your security group ID
  deploymentType: SCRATCH_2
  perUnitStorageThroughput: "200"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

```bash
# Apply storage classes
kubectl apply -f storage-classes.yaml

# Verify storage classes
kubectl get storageclass
```

## Step 7: Set Up Namespaces and Resource Quotas

```yaml
# namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ml-training
  labels:
    workload-type: training
    cost-center: research
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-inference
  labels:
    workload-type: inference
    cost-center: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-development
  labels:
    workload-type: development
    cost-center: research
---
# Resource quota for training namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: training-quota
  namespace: ml-training
spec:
  hard:
    requests.nvidia.com/gpu: "10"
    limits.nvidia.com/gpu: "10"
    requests.memory: "100Gi"
    requests.cpu: "50"
---
# Resource quota for inference namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: inference-quota
  namespace: ml-inference
spec:
  hard:
    requests.nvidia.com/gpu: "20"
    limits.nvidia.com/gpu: "20"
    requests.memory: "200Gi"
    requests.cpu: "100"
```

```bash
# Apply namespaces and quotas
kubectl apply -f namespaces.yaml

# Verify namespaces
kubectl get namespaces
kubectl describe quota -n ml-training
```

## Step 8: Configure Network Policies

```yaml
# network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ml-training-policy
  namespace: ml-training
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ml-training
    - namespaceSelector:
        matchLabels:
          name: monitoring
  egress:
  - {}  # Allow all egress for S3, ECR access
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ml-inference-policy
  namespace: ml-inference
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ml-inference
    - namespaceSelector:
        matchLabels:
          name: monitoring
    - podSelector: {}  # Allow ingress from same namespace
  egress:
  - {}  # Allow all egress
```

```bash
# Apply network policies
kubectl apply -f network-policies.yaml

# Verify network policies
kubectl get networkpolicy -A
```

## Step 9: Install Monitoring Stack

If not already installed via Terraform, install Prometheus and Grafana:

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false

# Verify installation
kubectl get pods -n monitoring
```

## Step 10: Configure GPU Monitoring

```yaml
# gpu-monitoring.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-dcgm-exporter
  namespace: monitoring
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
apiVersion: v1
kind: Service
metadata:
  name: nvidia-dcgm-exporter
  namespace: monitoring
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
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nvidia-dcgm-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

```bash
# Apply GPU monitoring
kubectl apply -f gpu-monitoring.yaml

# Verify DCGM exporter is running
kubectl get pods -n monitoring | grep dcgm
```

## Step 11: Verification and Testing

### Test GPU Access

```yaml
# gpu-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
  namespace: ml-development
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
```

```bash
# Run GPU test
kubectl apply -f gpu-test.yaml

# Check results
kubectl logs gpu-test -n ml-development

# Clean up
kubectl delete pod gpu-test -n ml-development
```

### Test Storage

```yaml
# storage-test.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: ml-development
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3-fast
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-test
  namespace: ml-development
spec:
  containers:
  - name: test
    image: busybox
    command: ["sh", "-c", "echo 'Storage test' > /data/test.txt && cat /data/test.txt"]
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
  restartPolicy: Never
```

```bash
# Test storage
kubectl apply -f storage-test.yaml

# Check results
kubectl logs storage-test -n ml-development

# Clean up
kubectl delete -f storage-test.yaml
```

### Test Autoscaling

```bash
# Check cluster autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Create a deployment that will trigger scaling
kubectl create deployment scale-test --image=nginx --replicas=20 -n ml-development

# Watch nodes scale up
kubectl get nodes -w

# Clean up
kubectl delete deployment scale-test -n ml-development
```

## Step 12: Access Grafana Dashboard

```bash
# Get Grafana admin password
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port forward to access Grafana
kubectl port-forward --namespace monitoring svc/prometheus-grafana 3000:80

# Access Grafana at http://localhost:3000
# Username: admin
# Password: (from above command)
```

## Troubleshooting

### Common Issues

**Nodes not joining the cluster:**
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name ai-ml-cluster --nodegroup-name <nodegroup-name>

# Check CloudFormation stack events
aws cloudformation describe-stack-events --stack-name <stack-name>
```

**GPU resources not available:**
```bash
# Check NVIDIA device plugin
kubectl get pods -n kube-system | grep nvidia
kubectl logs -n kube-system <nvidia-device-plugin-pod>

# Verify GPU nodes
kubectl describe nodes | grep -A 5 -B 5 nvidia.com/gpu
```

**Storage issues:**
```bash
# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi

# Check storage classes
kubectl get storageclass
kubectl describe storageclass gp3-fast
```

## Next Steps

Now that your cluster is set up, you can proceed to:

1. **[Deploy Inference Workloads](02-inference-deployment.md)** - Set up model serving
2. **[Set Up Training Environments](03-training-setup.md)** - Configure distributed training
3. **[Configure Storage](04-storage-configuration.md)** - Set up high-performance storage

## Clean Up

To destroy the infrastructure when no longer needed:

```bash
# Delete Kubernetes resources first
kubectl delete namespace ml-training ml-inference ml-development

# Destroy Terraform infrastructure
terraform destroy -var-file="terraform.tfvars"
```

## Repository References

This guide uses components from:
- **Base Infrastructure**: [/infra/base/terraform](../../infra/base/terraform)
- **Kubernetes Add-ons**: [/infra/base/kubernetes-addons](../../infra/base/kubernetes-addons)
- **Monitoring Setup**: [/infra/base/kubernetes-addons/prometheus](../../infra/base/kubernetes-addons/prometheus)
