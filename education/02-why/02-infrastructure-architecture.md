# Infrastructure Architecture Decisions

## The Decision

How should you architect your EKS infrastructure to support diverse AI/ML workloads efficiently, securely, and cost-effectively?

## Key Architectural Decisions

### 1. Cluster Strategy: Single vs. Multiple Clusters

#### Options Available

**Single Large Cluster:**
- One EKS cluster serving all AI/ML workloads
- Namespace-based isolation
- Shared resource pools
- Centralized management

**Multiple Specialized Clusters:**
- Separate clusters for training, inference, and development
- Workload-specific optimizations
- Enhanced isolation and security
- Independent scaling and management

**Hybrid Approach:**
- Production cluster for inference workloads
- Training cluster for batch workloads
- Development cluster for experimentation

#### Decision Criteria

**Choose Single Cluster When:**
- Resource sharing and efficiency are priorities
- Team size is small to medium (< 50 people)
- Workloads have similar security requirements
- Operational simplicity is important
- Budget constraints favor resource consolidation

**Choose Multiple Clusters When:**
- Strong isolation requirements between workloads
- Different compliance requirements (dev vs. prod)
- Significantly different resource patterns
- Large organization with multiple teams
- Risk tolerance favors blast radius reduction

#### Trade-offs Analysis

| Aspect | Single Cluster | Multiple Clusters |
|--------|----------------|-------------------|
| **Cost** | Lower (shared resources) | Higher (dedicated resources) |
| **Isolation** | Namespace-level | Cluster-level |
| **Management** | Simpler | More complex |
| **Resource Efficiency** | Higher | Lower |
| **Blast Radius** | Larger | Smaller |
| **Compliance** | Challenging | Easier |

### 2. Node Group Architecture

#### Options Available

**Homogeneous Node Groups:**
- Single instance type per node group
- Predictable resource allocation
- Simplified capacity planning
- Easier troubleshooting

**Heterogeneous Node Groups:**
- Mixed instance types within node groups
- Better resource utilization
- Cost optimization opportunities
- Increased complexity

**Workload-Specific Node Groups:**
- Dedicated node groups for specific workloads
- Optimized instance types and configurations
- Enhanced isolation and performance
- Higher operational overhead

#### Recommended Architecture

```yaml
# Training-optimized node group
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
nodeGroups:
  - name: training-gpu
    instanceTypes: ["p3.2xlarge", "p3.8xlarge", "p4d.24xlarge"]
    spot: true
    minSize: 0
    maxSize: 20
    labels:
      workload-type: training
      node-class: gpu-compute
    taints:
      - key: nvidia.com/gpu
        value: "true"
        effect: NoSchedule

  # Inference-optimized node group
  - name: inference-gpu
    instanceTypes: ["g4dn.xlarge", "g4dn.2xlarge"]
    spot: false
    minSize: 2
    maxSize: 10
    labels:
      workload-type: inference
      node-class: gpu-inference
    taints:
      - key: nvidia.com/gpu
        value: "true"
        effect: NoSchedule

  # CPU workloads
  - name: cpu-workloads
    instanceTypes: ["m5.large", "m5.xlarge", "m5.2xlarge"]
    spot: true
    minSize: 2
    maxSize: 50
    labels:
      workload-type: general
      node-class: cpu-compute
```

### 3. Networking Architecture

#### VPC Design Considerations

**Subnet Strategy:**
- Private subnets for worker nodes (security)
- Public subnets for load balancers (if needed)
- Dedicated subnets for different workload types
- Multi-AZ deployment for high availability

**IP Address Planning:**
- Large CIDR blocks for pod networking
- Consider future growth and scaling needs
- Plan for multiple clusters if using multi-cluster strategy
- Reserve IP ranges for different environments

#### Network Security

```yaml
# Network policy for ML workloads
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ml-training-policy
  namespace: ml-training
spec:
  podSelector:
    matchLabels:
      workload-type: training
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
  - to: []
    ports:
    - protocol: TCP
      port: 443  # HTTPS for S3, ECR
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
```

### 4. Storage Architecture

#### Storage Strategy Decision Matrix

| Use Case | Primary Storage | Secondary Storage | Caching Layer |
|----------|----------------|-------------------|---------------|
| **Model Training** | FSx for Lustre | S3 (datasets) | Local NVMe |
| **Model Inference** | EFS | S3 (models) | Local SSD |
| **Data Processing** | FSx for Lustre | S3 (raw data) | EBS gp3 |
| **Development** | EFS | S3 (experiments) | EBS gp3 |

#### Implementation Example

```yaml
# Storage class for high-performance training
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fsx-lustre-training
provisioner: fsx.csi.aws.com
parameters:
  subnetId: subnet-12345678
  securityGroupIds: sg-12345678
  s3ImportPath: s3://my-training-data
  s3ExportPath: s3://my-training-results
  deploymentType: PERSISTENT_2
  perUnitStorageThroughput: "1000"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

### 5. Security Architecture

#### Identity and Access Management

**Pod-Level Security:**
- Service accounts with minimal permissions
- IAM roles for service accounts (IRSA)
- Pod security standards enforcement
- Network policies for traffic control

**Node-Level Security:**
- Dedicated security groups for different workload types
- Instance metadata service v2 enforcement
- Systems Manager for patch management
- CloudWatch agent for monitoring

#### Implementation Example

```yaml
# Service account with IRSA for S3 access
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ml-training-sa
  namespace: ml-training
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/MLTrainingRole
---
# Pod security policy
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: ml-training-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

## Architectural Patterns

### Pattern 1: Shared Infrastructure with Workload Isolation

**When to Use:**
- Medium-sized teams (10-50 people)
- Mixed workload types with similar security requirements
- Cost optimization is important
- Operational simplicity is preferred

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                    Single EKS Cluster                       │
├─────────────────┬─────────────────┬─────────────────────────┤
│   Training NS   │  Inference NS   │    Development NS       │
│                 │                 │                         │
│ GPU Node Group  │ GPU Node Group  │   CPU Node Group        │
│ (Spot/On-Demand)│ (On-Demand)     │   (Spot)                │
└─────────────────┴─────────────────┴─────────────────────────┘
```

### Pattern 2: Workload-Specific Clusters

**When to Use:**
- Large organizations with multiple teams
- Strong compliance and isolation requirements
- Different SLA requirements for workloads
- Significant resource pattern differences

**Architecture:**
```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Training Cluster│  │Inference Cluster│  │   Dev Cluster   │
│                 │  │                 │  │                 │
│ GPU Nodes       │  │ GPU/CPU Nodes   │  │ CPU Nodes       │
│ (Spot Heavy)    │  │ (On-Demand)     │  │ (Spot)          │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Pattern 3: Hub and Spoke Model

**When to Use:**
- Multiple business units or teams
- Centralized governance with distributed execution
- Shared services and infrastructure
- Complex compliance requirements

**Architecture:**
```
                    ┌─────────────────┐
                    │  Shared Services│
                    │    Cluster      │
                    │ (Monitoring,    │
                    │  Logging, etc.) │
                    └─────────┬───────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼───────┐    ┌────────▼────────┐    ┌──────▼──────┐
│ Team A Cluster │    │ Team B Cluster  │    │ Prod Cluster│
│               │    │                 │    │             │
└───────────────┘    └─────────────────┘    └─────────────┘
```

## Cost Optimization Strategies

### 1. Right-Sizing Node Groups

**Training Workloads:**
- Use spot instances for fault-tolerant training
- Scale to zero when not in use
- Mix of instance types for availability

**Inference Workloads:**
- On-demand instances for production
- Right-size based on actual usage patterns
- Use smaller instances with horizontal scaling

### 2. Resource Sharing

**Shared GPU Pools:**
```yaml
# GPU sharing configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: gpu-sharing-config
data:
  config.yaml: |
    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: 4  # Share each GPU among 4 pods
```

**Cluster Autoscaler Configuration:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
spec:
  template:
    spec:
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/ai-cluster
        - --balance-similar-node-groups
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m
```

## Monitoring and Observability Architecture

### Centralized Monitoring Stack

```yaml
# Prometheus configuration for AI workloads
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
    - job_name: 'nvidia-dcgm'
      static_configs:
      - targets: ['dcgm-exporter:9400']
    - job_name: 'node-exporter'
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_endpoints_name]
        regex: node-exporter
        action: keep
```

## Disaster Recovery and Business Continuity

### Multi-AZ Deployment Strategy

```yaml
# Node group spread across AZs
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
nodeGroups:
  - name: inference-multi-az
    instanceTypes: ["g4dn.xlarge"]
    availabilityZones: ["us-west-2a", "us-west-2b", "us-west-2c"]
    minSize: 3
    maxSize: 15
    desiredCapacity: 6
    volumeSize: 100
    volumeType: gp3
```

### Backup and Recovery Strategy

**Model and Data Backup:**
- Automated S3 backups with lifecycle policies
- Cross-region replication for critical models
- Point-in-time recovery for training checkpoints

**Configuration Backup:**
- GitOps approach with configuration in version control
- Automated cluster configuration backups
- Infrastructure as Code for rapid recovery

## Next Steps

- Explore [Compute Resource Selection](03-compute-resource-selection.md) for hardware optimization
- Review [Scaling Strategy Decisions](04-scaling-strategies.md) for workload scaling
- Consider [Security Architecture Decisions](08-security-architecture.md) for comprehensive security

## Repository Examples

See these architectural implementations:

- **Base Infrastructure**: [Complete EKS setup](../../infra/base) with multi-node group configuration
- **Security Examples**: [Network policies and RBAC](../../infra/base/kubernetes-addons) configurations
- **Monitoring Stack**: [Observability setup](../../infra/base/kubernetes-addons/aws-load-balancer-controller) with Prometheus and Grafana
