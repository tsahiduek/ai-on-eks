# NVIDIA Dynamo Infrastructure

This directory contains the infrastructure configuration for deploying NVIDIA Dynamo on Amazon EKS using the ai-on-eks base infrastructure pattern.

## Overview

NVIDIA Dynamo infrastructure is designed as a reference architecture that combines the ai-on-eks base infrastructure modules with Dynamo-specific configurations for optimal performance and scalability.

## Directory Structure

```
infra/nvidia-dynamo/
├── install.sh                    # Main installation script
├── cleanup.sh                    # Infrastructure cleanup script
├── terraform/
│   ├── blueprint.tfvars          # Dynamo-specific configuration
│   ├── dynamo-*.tf               # Dynamo-specific Terraform modules
│   └── custom-*.tf               # Custom Karpenter configurations
└── scripts/
    └── manual-ecr-refresh.sh     # Manual ECR token refresh utility
```

## Architecture Components

This infrastructure includes:

### Pre-Cluster Components
- **VPC & Networking**: Standard ai-on-eks VPC with public/private subnets
- **EKS Cluster**: Kubernetes cluster with GPU-enabled node groups
- **ECR Repositories**: Container registries for Dynamo platform images
- **IAM Roles**: IRSA-enabled service accounts for ECR access
- **Security Groups**: Optimized for AI/ML workloads

### Post-Cluster Components
- **Dynamo Operator**: Kubernetes operator for managing inference graphs
- **Dynamo API Store**: RESTful API for graph deployment and management
- **Supporting Services**: NATS JetStream, PostgreSQL, MinIO
- **Monitoring Stack**: Prometheus, Grafana, ServiceMonitor resources
- **Custom Karpenter NodePools**: High-priority nodes for Dynamo workloads

## Configuration

### Core Settings

The infrastructure is configured via `terraform/blueprint.tfvars`:

```hcl
# Infrastructure naming and basic settings
name = "dynamo-on-eks"
enable_dynamo_stack = true

# Required components for Dynamo
enable_aws_efs_csi_driver = true
enable_kube_prometheus_stack = true
enable_aws_efa_k8s_device_plugin = true
enable_ai_ml_observability_stack = true

# Custom node pools for Dynamo workloads
enable_custom_karpenter_nodepools = true
use_bottlerocket = false
```

### Dynamo-Specific Features

- **ECR Token Refresh**: Automated credential rotation for container registries
- **IRSA Integration**: IAM roles for service accounts eliminate credential management
- **Custom Karpenter NodePools**: High-priority nodes optimized for AI/ML workloads
- **BuildKit Support**: Rootless container building with user namespace support

## Usage

### Installation

```bash
cd infra/nvidia-dynamo
./install.sh
```

The installation script will:
1. Copy base ai-on-eks infrastructure to local terraform directory
2. Apply Dynamo-specific configurations
3. Deploy infrastructure using Terraform
4. Set up Dynamo platform components
5. Configure monitoring and observability

### Customization

Override default settings by modifying `terraform/blueprint.tfvars`:

```hcl
# Enable additional components
enable_mlflow_tracking = true
enable_jupyterhub = true
enable_argo_workflows = true

# Adjust node pool weights
karpenter_g6_weight = 40
karpenter_g5_weight = 40
```

### Cleanup

```bash
cd infra/nvidia-dynamo
./cleanup.sh
```

## Integration with ai-on-eks

This infrastructure follows the ai-on-eks contribution patterns:

1. **Base Infrastructure**: Inherits from `infra/base/terraform`
2. **Modular Design**: Uses toggleable variables with defaults set to off
3. **ArgoCD Integration**: Post-cluster resources deployed via ArgoCD
4. **Documentation**: Complete documentation in `website/docs/`

## Monitoring and Observability

The infrastructure includes comprehensive monitoring:

- **Prometheus**: Metrics collection from all Dynamo components
- **Grafana**: Pre-configured dashboards for inference monitoring
- **ServiceMonitor**: Automatic service discovery and scraping
- **ECR Token Monitoring**: Alerts for credential refresh failures

## Security Features

- **IRSA**: IAM roles for service accounts eliminate long-lived credentials
- **Network Security**: Security groups optimized for AI/ML traffic patterns
- **Image Security**: ECR vulnerability scanning and image signing
- **Least Privilege**: Minimal IAM permissions for all components

## Performance Optimizations

- **Custom NodePools**: Higher-priority scheduling for Dynamo workloads
- **EFA Networking**: High-performance networking for GPU instances
- **EFS Storage**: Shared persistent storage for model caching
- **BuildKit**: Efficient container image building with caching

## Troubleshooting

Common issues and solutions:

1. **NodePool Creation**: Check Karpenter logs if nodes aren't provisioning
2. **ECR Access**: Verify IRSA configuration and service account annotations
3. **Platform Pods**: Check resource limits and node capacity
4. **Monitoring**: Ensure ServiceMonitor resources are created in correct namespace

## Contributing

When contributing to this infrastructure:

1. Follow the ai-on-eks contribution guidelines
2. Ensure all new features are toggleable with defaults off
3. Update documentation for any new variables or components
4. Test with both AL2023 and Bottlerocket AMIs
5. Maintain compatibility with the base infrastructure patterns

## Related Documentation

- [Main Documentation](../../website/docs/blueprints/inference/GPUs/nvidia-dynamo.md)
- [Blueprint Examples](../../blueprints/inference/nvidia-dynamo/)
- [AI-on-EKS Base Infrastructure](../base/terraform/)
- [NVIDIA Dynamo Official Docs](https://docs.nvidia.com/dynamo/)