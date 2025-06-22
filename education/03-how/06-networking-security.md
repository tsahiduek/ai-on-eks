# Networking and Security Implementation

This guide shows you how to implement network policies, security groups, and comprehensive security measures for AI/ML workloads on EKS.

## Prerequisites

- EKS cluster set up (see [Cluster Setup](01-cluster-setup.md))
- kubectl configured to access your cluster
- Understanding of Kubernetes networking and security concepts
- AWS CLI with appropriate permissions

## Overview

We'll implement:
1. VPC and subnet security configuration
2. Kubernetes network policies
3. Pod security standards and policies
4. Secrets management and encryption
5. RBAC and service account security
6. Runtime security monitoring

## Step 1: VPC Security Configuration

### Security Groups for AI/ML Workloads

```hcl
# Security group for ML training workloads
resource "aws_security_group" "ml_training" {
  name_prefix = "ml-training-"
  vpc_id      = var.vpc_id
  description = "Security group for ML training workloads"

  # Allow inbound from same security group (for distributed training)
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "Allow communication between training nodes"
  }

  # Allow inbound from monitoring
  ingress {
    from_port       = 8080
    to_port         = 8090
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
    description     = "Allow monitoring access"
  }

  # Allow outbound HTTPS for AWS services
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS services"
  }

  # Allow outbound for container registries
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for container registries"
  }

  # Allow DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS resolution"
  }

  tags = {
    Name = "ml-training-sg"
    Purpose = "ML training workloads"
  }
}

# Security group for ML inference workloads
resource "aws_security_group" "ml_inference" {
  name_prefix = "ml-inference-"
  vpc_id      = var.vpc_id
  description = "Security group for ML inference workloads"

  # Allow inbound from ALB
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }

  # Allow inbound from same security group
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "Inter-service communication"
  }

  # Allow outbound HTTPS
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for model downloads"
  }

  # Allow DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS resolution"
  }

  tags = {
    Name = "ml-inference-sg"
    Purpose = "ML inference workloads"
  }
}
```

### VPC Endpoints for Security

```hcl
# VPC endpoints for secure AWS service access
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.region}.s3"
  
  tags = {
    Name = "s3-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  tags = {
    Name = "ecr-api-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  tags = {
    Name = "ecr-dkr-vpc-endpoint"
  }
}
```

## Step 2: Kubernetes Network Policies

### Default Deny Network Policy

```yaml
# default-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ml-training
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ml-inference
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### ML Training Network Policies

```yaml
# ml-training-network-policies.yaml
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
  # Allow from same namespace
  - from:
    - namespaceSelector:
        matchLabels:
          name: ml-training
  
  # Allow from monitoring namespace
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080  # Metrics endpoint
    - protocol: TCP
      port: 8090  # Health endpoint
  
  egress:
  # Allow DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  
  # Allow HTTPS for AWS services
  - to: []
    ports:
    - protocol: TCP
      port: 443
  
  # Allow HTTP for container registries
  - to: []
    ports:
    - protocol: TCP
      port: 80
  
  # Allow communication within namespace
  - to:
    - namespaceSelector:
        matchLabels:
          name: ml-training
  
  # Allow communication to shared storage
  - to:
    - namespaceSelector:
        matchLabels:
          name: storage
    ports:
    - protocol: TCP
      port: 2049  # NFS for EFS
---
# Distributed training communication policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: distributed-training-policy
  namespace: ml-training
spec:
  podSelector:
    matchLabels:
      training-type: distributed
  policyTypes:
  - Ingress
  - Egress
  
  ingress:
  # Allow from other training pods
  - from:
    - podSelector:
        matchLabels:
          training-type: distributed
    ports:
    - protocol: TCP
      port: 29500  # PyTorch distributed default port
    - protocol: TCP
      port: 23456  # Ray default port
  
  egress:
  # Allow to other training pods
  - to:
    - podSelector:
        matchLabels:
          training-type: distributed
    ports:
    - protocol: TCP
      port: 29500
    - protocol: TCP
      port: 23456
```

### ML Inference Network Policies

```yaml
# ml-inference-network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ml-inference-policy
  namespace: ml-inference
spec:
  podSelector:
    matchLabels:
      workload-type: inference
  policyTypes:
  - Ingress
  - Egress
  
  ingress:
  # Allow from ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  
  # Allow from same namespace
  - from:
    - namespaceSelector:
        matchLabels:
          name: ml-inference
  
  # Allow from monitoring
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
  
  egress:
  # Allow DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
  
  # Allow HTTPS for model downloads
  - to: []
    ports:
    - protocol: TCP
      port: 443
  
  # Allow communication within namespace
  - to:
    - namespaceSelector:
        matchLabels:
          name: ml-inference
```

Apply network policies:

```bash
# Apply network policies
kubectl apply -f default-deny-all.yaml
kubectl apply -f ml-training-network-policies.yaml
kubectl apply -f ml-inference-network-policies.yaml

# Verify network policies
kubectl get networkpolicy -A
kubectl describe networkpolicy ml-training-policy -n ml-training
```

## Step 3: Pod Security Standards

### Pod Security Standards Configuration

```yaml
# pod-security-standards.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ml-training
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    name: ml-training
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-inference
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    name: ml-inference
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-development
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    name: ml-development
```

### Secure Pod Templates

```yaml
# secure-ml-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-ml-inference
  namespace: ml-inference
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-ml-inference
  template:
    metadata:
      labels:
        app: secure-ml-inference
        workload-type: inference
    spec:
      serviceAccountName: ml-inference-sa
      
      # Pod security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      
      containers:
      - name: inference
        image: ml-inference:secure
        
        # Container security context
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
        
        ports:
        - containerPort: 8080
          name: http
        
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "8Gi"
            cpu: "4"
          requests:
            nvidia.com/gpu: 1
            memory: "4Gi"
            cpu: "2"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        
        # Environment variables from secrets
        env:
        - name: MODEL_API_KEY
          valueFrom:
            secretKeyRef:
              name: model-secrets
              key: api-key
        
        # Volume mounts
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
        - name: models
          mountPath: /models
          readOnly: true
      
      # Volumes
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      - name: models
        persistentVolumeClaim:
          claimName: shared-models-pvc
      
      # Node selection and tolerations
      nodeSelector:
        node-class: gpu
        workload-type: inference
      
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

## Step 4: RBAC Configuration

### Service Accounts and Roles

```yaml
# rbac-configuration.yaml
# Service accounts
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ml-training-sa
  namespace: ml-training
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/MLTrainingRole
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ml-inference-sa
  namespace: ml-inference
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/MLInferenceRole
---
# Role for ML engineers
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ml-training
  name: ml-engineer
rules:
# Training jobs
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Pods for debugging
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "delete"]

# ConfigMaps and Secrets (limited)
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]

# PVCs
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "delete"]

# Services (read-only)
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch"]
---
# Role for ML operations
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ml-inference
  name: ml-ops
rules:
# Full access to deployments
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["*"]

# Services and ingress
- apiGroups: ["", "networking.k8s.io"]
  resources: ["services", "ingresses"]
  verbs: ["*"]

# HPA and scaling
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["*"]

# ConfigMaps and Secrets
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Pods (read-only for monitoring)
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
---
# Role bindings
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ml-engineers
  namespace: ml-training
subjects:
- kind: Group
  name: ml-engineers
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: ml-engineer-1
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: ml-engineer
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ml-ops-team
  namespace: ml-inference
subjects:
- kind: Group
  name: ml-ops
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: ml-ops
  apiGroup: rbac.authorization.k8s.io
```

Apply RBAC configuration:

```bash
# Apply RBAC configuration
kubectl apply -f rbac-configuration.yaml

# Verify service accounts
kubectl get sa -n ml-training
kubectl get sa -n ml-inference

# Test permissions
kubectl auth can-i create jobs --as=system:serviceaccount:ml-training:ml-training-sa -n ml-training
```

## Step 5: Secrets Management

### External Secrets Operator Setup

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --set installCRDs=true
```

### AWS Secrets Manager Integration

```yaml
# external-secrets-config.yaml
# Secret store for AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: ml-training
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
---
# External secret for ML API keys
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ml-api-keys
  namespace: ml-training
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: model-secrets
    creationPolicy: Owner
  data:
  - secretKey: openai-api-key
    remoteRef:
      key: ml/openai-api-key
  - secretKey: huggingface-token
    remoteRef:
      key: ml/huggingface-token
  - secretKey: wandb-api-key
    remoteRef:
      key: ml/wandb-api-key
---
# Service account for External Secrets
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: ml-training
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/ExternalSecretsRole
```

### Encryption at Rest

```yaml
# encrypted-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: encrypted-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  kmsKeyId: <arn>
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
```

## Step 6: Runtime Security Monitoring

### Falco Installation and Configuration

```bash
# Install Falco for runtime security
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
  --namespace falco-system \
  --create-namespace \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true
```

### Custom Falco Rules for ML Workloads

```yaml
# falco-ml-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-ml-rules
  namespace: falco-system
data:
  ml_rules.yaml: |
    - rule: Suspicious Model File Access
      desc: Detect unauthorized access to model files
      condition: >
        open_read and
        fd.name contains "/models/" and
        not proc.name in (python, python3, pytorch, tensorflow, tritonserver)
      output: >
        Suspicious access to model files (user=%user.name command=%proc.cmdline
        file=%fd.name container=%container.name image=%container.image.repository)
      priority: WARNING
      tags: [ml, model_security, file_access]
    
    - rule: Unexpected Network Connection from ML Pod
      desc: Detect unexpected network connections from ML workloads
      condition: >
        outbound and
        k8s.ns.name in (ml-training, ml-inference) and
        not fd.sip in (aws_metadata_service_ip, cluster_dns_ip) and
        not fd.sport in (80, 443, 53, 8080, 29500, 23456)
      output: >
        Unexpected network connection from ML pod (user=%user.name
        command=%proc.cmdline connection=%fd.name container=%container.name
        image=%container.image.repository)
      priority: WARNING
      tags: [ml, network_security, anomaly]
    
    - rule: Privilege Escalation in ML Container
      desc: Detect privilege escalation attempts in ML containers
      condition: >
        spawned_process and
        k8s.ns.name in (ml-training, ml-inference) and
        proc.name in (sudo, su, setuid_binaries) and
        not user.name in (root)
      output: >
        Privilege escalation attempt in ML container (user=%user.name
        command=%proc.cmdline container=%container.name image=%container.image.repository)
      priority: CRITICAL
      tags: [ml, privilege_escalation, security]
    
    - rule: Sensitive Data Access in ML Workload
      desc: Detect access to sensitive files in ML containers
      condition: >
        open_read and
        k8s.ns.name in (ml-training, ml-inference) and
        (fd.name contains "password" or fd.name contains "secret" or
         fd.name contains "key" or fd.name contains "token" or
         fd.name contains ".env")
      output: >
        Sensitive data access in ML workload (user=%user.name command=%proc.cmdline
        file=%fd.name container=%container.name image=%container.image.repository)
      priority: HIGH
      tags: [ml, data_security, sensitive_access]
```

## Step 7: Security Testing and Validation

### Network Policy Testing

```bash
# Test network policies
# Create test pods
kubectl run test-pod-1 --image=busybox --rm -it --restart=Never -n ml-training -- /bin/sh
kubectl run test-pod-2 --image=busybox --rm -it --restart=Never -n ml-inference -- /bin/sh

# Test connectivity (should fail due to network policies)
kubectl exec -it test-pod-1 -n ml-training -- wget -qO- http://test-pod-2.ml-inference:8080

# Test allowed connectivity
kubectl exec -it test-pod-1 -n ml-training -- nslookup google.com
```

### Security Scanning

```yaml
# security-scan-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: security-scan
  namespace: ml-training
spec:
  template:
    spec:
      serviceAccountName: security-scanner-sa
      containers:
      - name: scanner
        image: aquasec/trivy:latest
        command:
        - /bin/sh
        - -c
        - |
          # Scan container images
          trivy image --severity HIGH,CRITICAL ml-training:latest
          trivy image --severity HIGH,CRITICAL ml-inference:latest
          
          # Scan Kubernetes configurations
          trivy k8s --report summary cluster
      restartPolicy: Never
```

## Troubleshooting Security Issues

### Common Network Policy Issues

```bash
# Debug network policies
kubectl describe networkpolicy ml-training-policy -n ml-training

# Check if pods match selectors
kubectl get pods -n ml-training --show-labels

# Test connectivity
kubectl exec -it <pod-name> -n ml-training -- nc -zv <target-ip> <port>
```

### RBAC Troubleshooting

```bash
# Check permissions
kubectl auth can-i <verb> <resource> --as=<user> -n <namespace>

# Debug RBAC
kubectl describe rolebinding <binding-name> -n <namespace>
kubectl describe role <role-name> -n <namespace>
```

## Next Steps

- Set up [Monitoring](07-monitoring-setup.md) for security event monitoring
- Implement [CI/CD](08-cicd-setup.md) with security scanning
- Configure [Scaling](09-scaling-optimization.md) with security considerations

## Repository References

This guide uses:
- **Security Infrastructure**: [/infra/base/terraform](../../infra/base/terraform)
- **Network Policies**: [/infra/base/kubernetes-addons](../../infra/base/kubernetes-addons)
- **RBAC Examples**: [/blueprints](../../blueprints) security configurations
