# Storage Strategy Decisions

## The Decision

How should you architect your storage strategy to support AI/ML workloads efficiently, cost-effectively, and with the right performance characteristics?

## Storage Requirements Analysis

### AI/ML Workload Storage Patterns

#### Training Workloads
- **Large Datasets**: Terabytes to petabytes of training data
- **Sequential Access**: Reading large files sequentially during training
- **High Throughput**: Need sustained high bandwidth for data loading
- **Checkpoint Storage**: Frequent writes of model checkpoints
- **Temporary Storage**: Intermediate processing results

#### Inference Workloads
- **Model Artifacts**: Gigabytes of model weights and configurations
- **Random Access**: Loading specific models on demand
- **Low Latency**: Quick model loading for cold starts
- **Caching**: Frequently accessed models in fast storage
- **Shared Access**: Multiple pods accessing same models

#### Data Processing Workloads
- **Raw Data Ingestion**: Large volumes of unstructured data
- **Transformation Pipelines**: Intermediate data storage
- **Feature Stores**: Processed features for training and inference
- **Metadata Storage**: Experiment tracking and model registry

## Storage Options Analysis

### Amazon S3 (Object Storage)

#### When to Use S3
- **Data Archival**: Long-term storage of datasets and models
- **Data Lake**: Central repository for all AI/ML data
- **Cross-Region Access**: Data sharing across regions
- **Cost Optimization**: Lifecycle policies for different access patterns

#### S3 Performance Characteristics
```yaml
# S3 performance tiers
storage_classes:
  standard:
    cost_per_gb_month: 0.023
    retrieval_cost: 0.0004
    first_byte_latency: "100-200ms"
    throughput: "3,500 PUT/COPY/POST/DELETE, 5,500 GET/HEAD per prefix"
  
  intelligent_tiering:
    cost_per_gb_month: 0.0125  # varies by tier
    monitoring_cost: 0.0025
    automatic_optimization: true
  
  glacier:
    cost_per_gb_month: 0.004
    retrieval_time: "1-5 minutes"
    use_case: "archival"
```

#### S3 Optimization Strategies
```python
# S3 optimization for AI/ML workloads
import boto3
from concurrent.futures import ThreadPoolExecutor
import multiprocessing

class OptimizedS3Client:
    def __init__(self, region='us-west-2'):
        self.s3_client = boto3.client(
            's3',
            region_name=region,
            config=boto3.session.Config(
                max_pool_connections=50,  # Increase connection pool
                retries={'max_attempts': 3}
            )
        )
    
    def parallel_download(self, bucket, keys, local_dir, max_workers=None):
        """Download multiple files in parallel"""
        if max_workers is None:
            max_workers = min(32, multiprocessing.cpu_count() * 4)
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = []
            for key in keys:
                local_path = f"{local_dir}/{key.split('/')[-1]}"
                future = executor.submit(
                    self.s3_client.download_file,
                    bucket, key, local_path
                )
                futures.append(future)
            
            # Wait for all downloads to complete
            for future in futures:
                future.result()
    
    def multipart_upload(self, bucket, key, file_path, part_size=100*1024*1024):
        """Upload large files using multipart upload"""
        import os
        
        file_size = os.path.getsize(file_path)
        
        if file_size < part_size:
            # Use regular upload for small files
            self.s3_client.upload_file(file_path, bucket, key)
        else:
            # Use multipart upload for large files
            response = self.s3_client.create_multipart_upload(
                Bucket=bucket, Key=key
            )
            upload_id = response['UploadId']
            
            parts = []
            part_number = 1
            
            with open(file_path, 'rb') as f:
                while True:
                    data = f.read(part_size)
                    if not data:
                        break
                    
                    response = self.s3_client.upload_part(
                        Bucket=bucket,
                        Key=key,
                        PartNumber=part_number,
                        UploadId=upload_id,
                        Body=data
                    )
                    
                    parts.append({
                        'ETag': response['ETag'],
                        'PartNumber': part_number
                    })
                    part_number += 1
            
            # Complete multipart upload
            self.s3_client.complete_multipart_upload(
                Bucket=bucket,
                Key=key,
                UploadId=upload_id,
                MultipartUpload={'Parts': parts}
            )
```

### Amazon FSx for Lustre

#### When to Use FSx for Lustre
- **High-Performance Training**: Distributed training requiring high throughput
- **Large-Scale Data Processing**: Parallel processing of large datasets
- **Scratch Storage**: Temporary high-performance storage for training jobs
- **S3 Integration**: Direct integration with S3 for data loading

#### FSx Performance Characteristics
```yaml
# FSx for Lustre performance tiers
deployment_types:
  scratch_1:
    throughput_per_tib: "200 MB/s"
    cost_per_tib_month: 140
    use_case: "temporary high-performance"
  
  scratch_2:
    throughput_per_tib: "400 MB/s"
    cost_per_tib_month: 150
    use_case: "higher performance temporary"
  
  persistent_1:
    throughput_per_tib: "50-200 MB/s"
    cost_per_tib_month: 145
    backup_support: true
    use_case: "long-term high-performance"
  
  persistent_2:
    throughput_per_tib: "125-1000 MB/s"
    cost_per_tib_month: 290
    backup_support: true
    use_case: "maximum performance"
```

#### FSx Kubernetes Integration
```yaml
# FSx StorageClass for training workloads
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
  # Auto import/export
  autoImportPolicy: NEW_CHANGED
  autoExportPolicy: NEW_CHANGED
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
# PVC for training job
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: training-data-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: fsx-lustre-training
  resources:
    requests:
      storage: 1200Gi  # 1.2 TiB minimum
```

### Amazon EFS (Elastic File System)

#### When to Use EFS
- **Shared Model Storage**: Multiple pods accessing same models
- **Development Environments**: Shared notebooks and code
- **Small to Medium Datasets**: Datasets under 1TB
- **Multi-AZ Access**: Cross-AZ file sharing

#### EFS Performance Modes
```yaml
# EFS performance configurations
performance_modes:
  general_purpose:
    max_iops: 7000
    latency: "lowest"
    use_case: "most workloads"
  
  max_io:
    max_iops: "higher than 7000"
    latency: "slightly higher"
    use_case: "high concurrent access"

throughput_modes:
  bursting:
    baseline: "50 MiB/s per TiB"
    burst: "100 MiB/s per TiB"
    cost: "storage only"
  
  provisioned:
    throughput: "up to 4 GiB/s"
    cost: "storage + provisioned throughput"
```

#### EFS Kubernetes Configuration
```yaml
# EFS StorageClass for shared model storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-models
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-12345678
  directoryPerms: "0755"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
  basePath: "/models"
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# PVC for model storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-models-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-models
  resources:
    requests:
      storage: 100Gi
```

### Local NVMe Storage

#### When to Use Local Storage
- **Ultra-Low Latency**: Inference workloads requiring minimal latency
- **Temporary Caching**: Fast cache for frequently accessed data
- **Checkpoint Storage**: Fast writes for training checkpoints
- **Data Processing**: Temporary storage for ETL operations

#### Local Storage Configuration
```yaml
# Local storage configuration
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-nvme
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
---
# Local PV for NVMe storage
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-nvme-pv
spec:
  capacity:
    storage: 1000Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-nvme
  local:
    path: /mnt/nvme
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node-with-nvme
```

## Storage Architecture Patterns

### Pattern 1: Tiered Storage for Training

```yaml
# Multi-tier storage architecture
training_storage_tiers:
  # Tier 1: Hot data (current training)
  hot_storage:
    type: "FSx Lustre"
    size: "2.4 TiB"
    throughput: "1000 MB/s"
    cost_per_month: 580
    use_case: "active training data"
  
  # Tier 2: Warm data (recent datasets)
  warm_storage:
    type: "EFS"
    size: "10 TiB"
    throughput: "500 MB/s"
    cost_per_month: 3000
    use_case: "recent datasets, shared models"
  
  # Tier 3: Cold data (archived datasets)
  cold_storage:
    type: "S3 Standard-IA"
    size: "100 TiB"
    cost_per_month: 1250
    use_case: "archived datasets, model versions"
  
  # Tier 4: Archive (long-term retention)
  archive_storage:
    type: "S3 Glacier"
    size: "1 PiB"
    cost_per_month: 4096
    use_case: "compliance, long-term archive"
```

### Pattern 2: Inference-Optimized Storage

```yaml
# Inference storage architecture
inference_storage_pattern:
  # Model cache (local NVMe)
  model_cache:
    type: "Local NVMe"
    size: "500 GB"
    latency: "<1ms"
    use_case: "frequently used models"
  
  # Model repository (EFS)
  model_repository:
    type: "EFS"
    size: "5 TiB"
    throughput: "250 MB/s"
    use_case: "all model versions"
  
  # Model archive (S3)
  model_archive:
    type: "S3 Standard"
    size: "50 TiB"
    use_case: "model artifacts, backups"
```

### Pattern 3: Data Lake Architecture

```yaml
# Data lake storage architecture
data_lake_architecture:
  # Raw data ingestion
  raw_zone:
    storage: "S3 Standard"
    structure: "unprocessed data"
    retention: "7 years"
    lifecycle: "transition to IA after 30 days"
  
  # Processed data
  processed_zone:
    storage: "S3 Standard"
    structure: "cleaned, validated data"
    retention: "5 years"
    lifecycle: "transition to IA after 90 days"
  
  # Feature store
  feature_zone:
    storage: "S3 Standard + EFS"
    structure: "engineered features"
    retention: "3 years"
    access_pattern: "frequent read"
  
  # Model artifacts
  model_zone:
    storage: "S3 Standard"
    structure: "trained models, metadata"
    retention: "indefinite"
    versioning: "enabled"
```

## Cost Optimization Strategies

### S3 Lifecycle Policies

```json
{
  "Rules": [
    {
      "ID": "MLDataLifecycle",
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
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
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
      ],
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "NoncurrentDays": 90,
          "StorageClass": "GLACIER"
        }
      ]
    },
    {
      "ID": "TrainingCheckpoints",
      "Status": "Enabled",
      "Filter": {"Prefix": "checkpoints/"},
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
```

### Storage Cost Analysis

```python
# Storage cost analysis tool
class StorageCostAnalyzer:
    def __init__(self):
        self.s3_costs = {
            'standard': 0.023,
            'standard_ia': 0.0125,
            'glacier': 0.004,
            'deep_archive': 0.00099
        }
        
        self.efs_costs = {
            'standard': 0.30,
            'ia': 0.025
        }
        
        self.fsx_costs = {
            'scratch_1': 0.140,
            'scratch_2': 0.150,
            'persistent_1': 0.145,
            'persistent_2': 0.290
        }
    
    def calculate_monthly_cost(self, storage_config):
        """Calculate monthly storage costs"""
        total_cost = 0
        
        for storage_type, config in storage_config.items():
            if storage_type.startswith('s3'):
                storage_class = config['storage_class']
                size_gb = config['size_gb']
                cost_per_gb = self.s3_costs[storage_class]
                total_cost += size_gb * cost_per_gb
                
                # Add request costs
                if 'requests_per_month' in config:
                    request_cost = self.calculate_s3_request_cost(
                        config['requests_per_month'],
                        storage_class
                    )
                    total_cost += request_cost
            
            elif storage_type.startswith('efs'):
                size_gb = config['size_gb']
                storage_class = config.get('storage_class', 'standard')
                cost_per_gb = self.efs_costs[storage_class]
                total_cost += size_gb * cost_per_gb
            
            elif storage_type.startswith('fsx'):
                size_tib = config['size_tib']
                deployment_type = config['deployment_type']
                cost_per_tib = self.fsx_costs[deployment_type]
                total_cost += size_tib * cost_per_tib
        
        return total_cost
    
    def optimize_storage_strategy(self, workload_requirements):
        """Recommend optimal storage strategy"""
        recommendations = []
        
        # Analyze access patterns
        if workload_requirements['access_frequency'] == 'high':
            if workload_requirements['throughput_required'] > 1000:
                recommendations.append({
                    'storage': 'FSx Lustre',
                    'reason': 'High throughput requirement'
                })
            else:
                recommendations.append({
                    'storage': 'EFS',
                    'reason': 'High frequency, moderate throughput'
                })
        
        elif workload_requirements['access_frequency'] == 'medium':
            recommendations.append({
                'storage': 'S3 Standard',
                'reason': 'Balanced cost and performance'
            })
        
        else:  # low frequency
            recommendations.append({
                'storage': 'S3 Standard-IA or Glacier',
                'reason': 'Cost optimization for infrequent access'
            })
        
        return recommendations

# Example usage
analyzer = StorageCostAnalyzer()

storage_config = {
    's3_training_data': {
        'storage_class': 'standard',
        'size_gb': 10000,  # 10 TB
        'requests_per_month': 100000
    },
    'efs_models': {
        'storage_class': 'standard',
        'size_gb': 1000  # 1 TB
    },
    'fsx_scratch': {
        'deployment_type': 'scratch_2',
        'size_tib': 2.4
    }
}

monthly_cost = analyzer.calculate_monthly_cost(storage_config)
print(f"Monthly storage cost: ${monthly_cost:.2f}")
```

## Performance Optimization

### Data Loading Optimization

```python
# Optimized data loading patterns
import asyncio
import aiofiles
import torch
from torch.utils.data import Dataset, DataLoader

class OptimizedDataset(Dataset):
    def __init__(self, data_paths, cache_size=1000):
        self.data_paths = data_paths
        self.cache = {}
        self.cache_size = cache_size
        self.access_count = {}
    
    def __len__(self):
        return len(self.data_paths)
    
    def __getitem__(self, idx):
        path = self.data_paths[idx]
        
        # Check cache first
        if path in self.cache:
            self.access_count[path] = self.access_count.get(path, 0) + 1
            return self.cache[path]
        
        # Load from storage
        data = self.load_data(path)
        
        # Add to cache if space available
        if len(self.cache) < self.cache_size:
            self.cache[path] = data
            self.access_count[path] = 1
        else:
            # Evict least accessed item
            least_accessed = min(self.access_count.items(), key=lambda x: x[1])
            del self.cache[least_accessed[0]]
            del self.access_count[least_accessed[0]]
            
            self.cache[path] = data
            self.access_count[path] = 1
        
        return data
    
    def load_data(self, path):
        """Load data with optimizations based on storage type"""
        if path.startswith('s3://'):
            return self.load_from_s3(path)
        elif path.startswith('/fsx/'):
            return self.load_from_fsx(path)
        else:
            return self.load_from_local(path)
    
    async def prefetch_data(self, indices):
        """Asynchronously prefetch data"""
        tasks = []
        for idx in indices:
            if self.data_paths[idx] not in self.cache:
                task = self.async_load_data(self.data_paths[idx])
                tasks.append(task)
        
        if tasks:
            await asyncio.gather(*tasks)
```

### Caching Strategies

```yaml
# Multi-level caching architecture
caching_strategy:
  # Level 1: In-memory cache
  l1_cache:
    type: "Redis"
    size: "64 GB"
    latency: "<1ms"
    use_case: "hot model weights"
  
  # Level 2: Local SSD cache
  l2_cache:
    type: "Local NVMe"
    size: "1 TB"
    latency: "<10ms"
    use_case: "frequently accessed models"
  
  # Level 3: Network storage
  l3_cache:
    type: "EFS"
    size: "10 TB"
    latency: "<100ms"
    use_case: "all available models"
  
  # Level 4: Object storage
  l4_storage:
    type: "S3"
    size: "unlimited"
    latency: "100-200ms"
    use_case: "model archive"
```

## Security and Compliance

### Encryption Strategies

```yaml
# Encryption configuration for different storage types
encryption_config:
  s3_encryption:
    server_side_encryption: "AES256"
    kms_key_id: "<arn>"
    bucket_key_enabled: true
  
  efs_encryption:
    encryption_at_rest: true
    encryption_in_transit: true
    kms_key_id: "<arn>"
  
  fsx_encryption:
    encryption_at_rest: true
    kms_key_id: "<arn>"
```

### Access Control

```yaml
# IAM policies for storage access
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ml-storage-access
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/MLStorageRole
---
# Role with least privilege access
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::ml-training-data/*",
        "arn:aws:s3:::ml-models/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "fsx:DescribeFileSystems"
      ],
      "Resource": "*"
    }
  ]
}
```

## Next Steps

- Review [Observability Choices](07-observability-choices.md) for monitoring storage performance
- Explore [Security Architecture](08-security-architecture.md) for comprehensive security
- Consider [Cost Optimization](10-cost-optimization.md) for storage cost management

## Repository Examples

See storage implementations:
- **FSx Integration**: [High-performance training storage](../../infra/base/terraform/fsx.tf)
- **S3 Integration**: [Model artifact storage](../../blueprints/inference/vllm-rayserve-gpu)
- **EFS Setup**: [Shared model storage](../../infra/base/terraform/efs.tf)
