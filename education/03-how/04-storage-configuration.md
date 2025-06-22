# Storage Configuration for AI/ML

This guide shows you how to configure different storage solutions for AI/ML workloads on EKS, including FSx for Lustre, EFS, and S3 integration.

## Prerequisites

- EKS cluster set up (see [Cluster Setup](01-cluster-setup.md))
- kubectl configured to access your cluster
- AWS CLI with appropriate permissions
- Understanding of Kubernetes storage concepts

## Overview

We'll configure:
1. FSx for Lustre for high-performance training workloads
2. EFS for shared model storage
3. S3 integration for data lakes and model artifacts
4. Local NVMe storage for caching
5. Storage optimization and monitoring

## Option 1: FSx for Lustre Setup

### Step 1: Create FSx File System

First, create an FSx for Lustre file system:

```bash
# Create FSx file system via AWS CLI
aws fsx create-file-system \
  --file-system-type LUSTRE \
  --lustre-configuration SubnetIds=subnet-12345678,DeploymentType=SCRATCH_2,PerUnitStorageThroughput=400,DataRepositoryConfiguration='{ImportPath=s3://my-training-data,ExportPath=s3://my-training-results,ImportedFileChunkSize=1024}' \
  --storage-capacity 1200 \
  --security-group-ids sg-12345678 \
  --tags Key=Name,Value=ml-training-fsx
```

Or use Terraform:

```hcl
# fsx.tf
resource "aws_fsx_lustre_file_system" "ml_training" {
  storage_capacity    = 1200  # 1.2 TiB minimum
  subnet_ids         = [var.private_subnet_ids[0]]
  deployment_type    = "SCRATCH_2"
  per_unit_storage_throughput = 400
  
  data_repository_configuration {
    import_path      = "s3://${var.training_data_bucket}"
    export_path      = "s3://${var.training_results_bucket}"
    imported_file_chunk_size = 1024
    auto_import_policy = "NEW_CHANGED"
    auto_export_policy = "NEW_CHANGED"
  }
  
  security_group_ids = [aws_security_group.fsx.id]
  
  tags = {
    Name = "ml-training-fsx"
    Environment = var.environment
  }
}

# Security group for FSx
resource "aws_security_group" "fsx" {
  name_prefix = "fsx-lustre-"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  ingress {
    from_port   = 1021
    to_port     = 1023
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "fsx-lustre-sg"
  }
}
```

### Step 2: Install FSx CSI Driver

```bash
# Install FSx CSI driver
kubectl apply -k "github.com/kubernetes-sigs/aws-fsx-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.1"

# Verify installation
kubectl get pods -n kube-system | grep fsx-csi
```

### Step 3: Create FSx StorageClass

```yaml
# fsx-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fsx-lustre-training
provisioner: fsx.csi.aws.com
parameters:
  subnetId: subnet-12345678
  securityGroupIds: sg-12345678
  deploymentType: SCRATCH_2
  perUnitStorageThroughput: "400"
  # S3 integration
  s3ImportPath: s3://my-training-data
  s3ExportPath: s3://my-training-results
  autoImportPolicy: NEW_CHANGED
  autoExportPolicy: NEW_CHANGED
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: false
```

### Step 4: Create PVC for Training Workloads

```yaml
# training-storage-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: training-data-pvc
  namespace: ml-training
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: fsx-lustre-training
  resources:
    requests:
      storage: 1200Gi  # Must match FSx file system size
---
# Checkpoint storage PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: training-checkpoints-pvc
  namespace: ml-training
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: fsx-lustre-training
  resources:
    requests:
      storage: 1200Gi
```

Apply the configurations:

```bash
# Apply storage configurations
kubectl apply -f fsx-storageclass.yaml
kubectl apply -f training-storage-pvc.yaml

# Verify PVC status
kubectl get pvc -n ml-training
```

## Option 2: EFS Setup for Shared Storage

### Step 1: Create EFS File System

```bash
# Create EFS file system
aws efs create-file-system \
  --creation-token ml-shared-storage-$(date +%s) \
  --performance-mode generalPurpose \
  --throughput-mode provisioned \
  --provisioned-throughput-in-mibps 500 \
  --encrypted \
  --tags Key=Name,Value=ml-shared-efs
```

Or with Terraform:

```hcl
# efs.tf
resource "aws_efs_file_system" "ml_shared" {
  creation_token = "ml-shared-storage"
  
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 500
  
  encrypted = true
  kms_key_id = aws_kms_key.efs.arn
  
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  
  tags = {
    Name = "ml-shared-efs"
    Environment = var.environment
  }
}

# Mount targets for each AZ
resource "aws_efs_mount_target" "ml_shared" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.ml_shared.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# Security group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "efs-"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "efs-sg"
  }
}

# KMS key for EFS encryption
resource "aws_kms_key" "efs" {
  description             = "KMS key for EFS encryption"
  deletion_window_in_days = 7
  
  tags = {
    Name = "efs-kms-key"
  }
}
```

### Step 2: Install EFS CSI Driver

```bash
# Install EFS CSI driver
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.7"

# Verify installation
kubectl get pods -n kube-system | grep efs-csi
```

### Step 3: Create EFS StorageClass and PVC

```yaml
# efs-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-models
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-12345678  # Replace with your EFS ID
  directoryPerms: "0755"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
  basePath: "/models"
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# PVC for shared model storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-models-pvc
  namespace: ml-inference
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-models
  resources:
    requests:
      storage: 100Gi
---
# PVC for shared notebooks
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-notebooks-pvc
  namespace: ml-development
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-models
  resources:
    requests:
      storage: 50Gi
```

Apply EFS configurations:

```bash
# Apply EFS configurations
kubectl apply -f efs-storageclass.yaml

# Verify PVC status
kubectl get pvc -A | grep efs
```

## Option 3: S3 Integration

### Step 1: Configure S3 Buckets

Create S3 buckets for different purposes:

```bash
# Create buckets for different data types
aws s3 mb s3://ml-training-datasets-$(date +%s)
aws s3 mb s3://ml-model-artifacts-$(date +%s)
aws s3 mb s3://ml-experiment-results-$(date +%s)

# Configure lifecycle policies
cat > lifecycle-policy.json << 'EOF'
{
  "Rules": [
    {
      "ID": "TrainingDataLifecycle",
      "Status": "Enabled",
      "Filter": {"Prefix": "datasets/"},
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    },
    {
      "ID": "ModelArtifactLifecycle",
      "Status": "Enabled",
      "Filter": {"Prefix": "models/"},
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "STANDARD_IA"
        }
      ]
    }
  ]
}
EOF

# Apply lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
  --bucket ml-training-datasets-$(date +%s) \
  --lifecycle-configuration file://lifecycle-policy.json
```

### Step 2: Configure S3 Access for Pods

```yaml
# s3-access-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-access-sa
  namespace: ml-training
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/S3AccessRole
---
# IAM role for S3 access (create via AWS CLI or Terraform)
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::ml-training-datasets-*",
        "arn:aws:s3:::ml-training-datasets-*/*",
        "arn:aws:s3:::ml-model-artifacts-*",
        "arn:aws:s3:::ml-model-artifacts-*/*"
      ]
    }
  ]
}
```

### Step 3: Create S3 Data Loading Job

```python
# s3-data-loader.py
import boto3
import os
import concurrent.futures
from pathlib import Path

class S3DataLoader:
    def __init__(self, bucket_name, region='us-west-2'):
        self.s3_client = boto3.client('s3', region_name=region)
        self.bucket_name = bucket_name
    
    def download_dataset(self, s3_prefix, local_path, max_workers=10):
        """Download dataset from S3 to local storage"""
        
        # List objects in S3
        paginator = self.s3_client.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=self.bucket_name, Prefix=s3_prefix)
        
        download_tasks = []
        for page in pages:
            if 'Contents' in page:
                for obj in page['Contents']:
                    s3_key = obj['Key']
                    local_file = Path(local_path) / Path(s3_key).name
                    download_tasks.append((s3_key, str(local_file)))
        
        # Download files in parallel
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = []
            for s3_key, local_file in download_tasks:
                future = executor.submit(self._download_file, s3_key, local_file)
                futures.append(future)
            
            # Wait for all downloads to complete
            for future in concurrent.futures.as_completed(futures):
                try:
                    future.result()
                except Exception as e:
                    print(f"Download failed: {e}")
    
    def _download_file(self, s3_key, local_file):
        """Download a single file from S3"""
        os.makedirs(os.path.dirname(local_file), exist_ok=True)
        self.s3_client.download_file(self.bucket_name, s3_key, local_file)
        print(f"Downloaded: {s3_key} -> {local_file}")
    
    def upload_results(self, local_path, s3_prefix, max_workers=10):
        """Upload results to S3"""
        
        # Find all files to upload
        upload_tasks = []
        for root, dirs, files in os.walk(local_path):
            for file in files:
                local_file = os.path.join(root, file)
                relative_path = os.path.relpath(local_file, local_path)
                s3_key = f"{s3_prefix}/{relative_path}"
                upload_tasks.append((local_file, s3_key))
        
        # Upload files in parallel
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = []
            for local_file, s3_key in upload_tasks:
                future = executor.submit(self._upload_file, local_file, s3_key)
                futures.append(future)
            
            # Wait for all uploads to complete
            for future in concurrent.futures.as_completed(futures):
                try:
                    future.result()
                except Exception as e:
                    print(f"Upload failed: {e}")
    
    def _upload_file(self, local_file, s3_key):
        """Upload a single file to S3"""
        self.s3_client.upload_file(local_file, self.bucket_name, s3_key)
        print(f"Uploaded: {local_file} -> s3://{self.bucket_name}/{s3_key}")

# Usage in training job
if __name__ == "__main__":
    loader = S3DataLoader(os.environ['S3_BUCKET'])
    
    # Download training data
    loader.download_dataset(
        s3_prefix="datasets/imagenet",
        local_path="/data/training"
    )
    
    # Upload results after training
    loader.upload_results(
        local_path="/results",
        s3_prefix="experiments/run-001"
    )
```

## Option 4: Local NVMe Storage Configuration

### Step 1: Configure Local Storage

```yaml
# local-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-nvme
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
---
# Discover and create local PVs
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-storage-config
  namespace: kube-system
data:
  storageClassMap: |
    local-nvme:
       hostDir: /mnt/nvme
       mountDir: /mnt/nvme
       blockCleanerCommand:
         - "/scripts/shred.sh"
         - "2"
       volumeMode: Filesystem
       fsType: ext4
---
# DaemonSet to provision local storage
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: local-volume-provisioner
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: local-volume-provisioner
  template:
    metadata:
      labels:
        app: local-volume-provisioner
    spec:
      serviceAccount: local-storage-admin
      containers:
      - image: quay.io/external_storage/local-volume-provisioner:v2.5.0
        name: provisioner
        securityContext:
          privileged: true
        env:
        - name: MY_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: MY_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: JOB_CONTAINER_IMAGE
          value: quay.io/external_storage/local-volume-provisioner:v2.5.0
        volumeMounts:
        - mountPath: /etc/provisioner/config
          name: provisioner-config
          readOnly: true
        - mountPath: /mnt/nvme
          name: local-nvme
          mountPropagation: "HostToContainer"
      volumes:
      - name: provisioner-config
        configMap:
          name: local-storage-config
      - name: local-nvme
        hostPath:
          path: /mnt/nvme
      nodeSelector:
        storage-type: nvme
```

### Step 2: Format and Mount NVMe Drives

Create a script to format NVMe drives on nodes:

```bash
#!/bin/bash
# format-nvme.sh - Run on each node with NVMe storage

# Find NVMe devices
NVME_DEVICES=$(lsblk -d -o name,rota | awk '$2=="0" && $1 ~ /^nvme/ {print "/dev/"$1}')

for device in $NVME_DEVICES; do
    echo "Formatting $device"
    
    # Create filesystem
    mkfs.ext4 -F $device
    
    # Create mount point
    mkdir -p /mnt/nvme
    
    # Mount device
    mount $device /mnt/nvme
    
    # Add to fstab for persistence
    echo "$device /mnt/nvme ext4 defaults 0 2" >> /etc/fstab
    
    # Set permissions
    chmod 755 /mnt/nvme
done
```

## Storage Performance Testing

### Step 1: Create Storage Benchmark Job

```yaml
# storage-benchmark.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: storage-benchmark
  namespace: ml-training
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: benchmark
        image: ubuntu:20.04
        command:
        - /bin/bash
        - -c
        - |
          apt-get update && apt-get install -y fio
          
          echo "=== FSx Lustre Benchmark ==="
          fio --name=fsx-test --directory=/fsx --rw=write --bs=1M --size=10G --numjobs=4 --group_reporting
          fio --name=fsx-test --directory=/fsx --rw=read --bs=1M --size=10G --numjobs=4 --group_reporting
          
          echo "=== EFS Benchmark ==="
          fio --name=efs-test --directory=/efs --rw=write --bs=1M --size=1G --numjobs=2 --group_reporting
          fio --name=efs-test --directory=/efs --rw=read --bs=1M --size=1G --numjobs=2 --group_reporting
          
          echo "=== Local NVMe Benchmark ==="
          fio --name=nvme-test --directory=/nvme --rw=write --bs=1M --size=5G --numjobs=4 --group_reporting
          fio --name=nvme-test --directory=/nvme --rw=read --bs=1M --size=5G --numjobs=4 --group_reporting
        volumeMounts:
        - name: fsx-storage
          mountPath: /fsx
        - name: efs-storage
          mountPath: /efs
        - name: nvme-storage
          mountPath: /nvme
        resources:
          limits:
            cpu: "4"
            memory: "8Gi"
          requests:
            cpu: "2"
            memory: "4Gi"
      volumes:
      - name: fsx-storage
        persistentVolumeClaim:
          claimName: training-data-pvc
      - name: efs-storage
        persistentVolumeClaim:
          claimName: shared-models-pvc
      - name: nvme-storage
        persistentVolumeClaim:
          claimName: nvme-cache-pvc
```

Run the benchmark:

```bash
# Run storage benchmark
kubectl apply -f storage-benchmark.yaml

# Monitor benchmark progress
kubectl logs -f job/storage-benchmark -n ml-training
```

## Storage Monitoring

### Step 1: Deploy Storage Monitoring

```yaml
# storage-monitoring.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-monitoring-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'node-exporter'
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_endpoints_name]
        regex: node-exporter
        action: keep
    
    - job_name: 'fsx-exporter'
      static_configs:
      - targets: ['fsx-exporter:9100']
    
    - job_name: 'efs-exporter'
      static_configs:
      - targets: ['efs-exporter:9100']
---
# Grafana dashboard for storage metrics
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-dashboard
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "Storage Performance Dashboard",
        "panels": [
          {
            "title": "Disk I/O",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(node_disk_read_bytes_total[5m])",
                "legendFormat": "Read {{device}}"
              },
              {
                "expr": "rate(node_disk_written_bytes_total[5m])",
                "legendFormat": "Write {{device}}"
              }
            ]
          },
          {
            "title": "Storage Utilization",
            "type": "graph",
            "targets": [
              {
                "expr": "(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100",
                "legendFormat": "{{mountpoint}}"
              }
            ]
          }
        ]
      }
    }
```

## Troubleshooting Storage Issues

### Common Issues and Solutions

**FSx mount failures:**
```bash
# Check FSx file system status
aws fsx describe-file-systems --file-system-ids fs-12345678

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-12345678

# Check mount logs
kubectl logs -n kube-system -l app=fsx-csi-node
```

**EFS performance issues:**
```bash
# Check EFS throughput mode
aws efs describe-file-systems --file-system-id fs-12345678

# Monitor EFS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name TotalIOBytes \
  --dimensions Name=FileSystemId,Value=fs-12345678 \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-01T01:00:00Z \
  --period 300 \
  --statistics Sum
```

**S3 access issues:**
```bash
# Test S3 access from pod
kubectl exec -it <pod-name> -- aws s3 ls s3://my-bucket/

# Check IAM role permissions
aws iam get-role-policy --role-name S3AccessRole --policy-name S3Policy
```

## Next Steps

- Set up [GPU and Hardware](05-hardware-setup.md) for compute optimization
- Configure [Monitoring](07-monitoring-setup.md) for storage observability
- Implement [CI/CD](08-cicd-setup.md) for automated deployments

## Repository References

This guide uses:
- **Storage Infrastructure**: [/infra/base/terraform](../../infra/base/terraform)
- **Storage Classes**: [/infra/base/kubernetes-addons](../../infra/base/kubernetes-addons)
- **Training Examples**: [/blueprints/training](../../blueprints/training)
