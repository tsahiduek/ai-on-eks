# Security Architecture Decisions

## The Decision

How should you design your security architecture to protect AI/ML workloads, data, and models while maintaining operational efficiency and compliance requirements?

## AI/ML Security Threat Landscape

### Unique Security Challenges

#### Model-Specific Threats
- **Model Theft**: Unauthorized access to proprietary models
- **Model Poisoning**: Malicious training data injection
- **Adversarial Attacks**: Crafted inputs to fool models
- **Model Inversion**: Extracting training data from models
- **Prompt Injection**: Manipulating LLM behavior through inputs

#### Data Security Risks
- **Training Data Exposure**: Sensitive data in training datasets
- **Data Poisoning**: Corrupted training data
- **Feature Extraction**: Inferring sensitive information from features
- **Data Lineage**: Tracking data provenance and usage

#### Infrastructure Vulnerabilities
- **Container Escape**: Breaking out of containerized environments
- **Privilege Escalation**: Gaining unauthorized access levels
- **Supply Chain Attacks**: Compromised dependencies and images
- **Secrets Exposure**: API keys, credentials in code or logs

## Security Architecture Patterns

### Pattern 1: Defense in Depth

```yaml
# Multi-layered security architecture
security_layers:
  # Network Security
  network:
    - "VPC isolation with private subnets"
    - "Security groups with least privilege"
    - "Network policies for pod-to-pod communication"
    - "WAF for external-facing services"
    - "VPC endpoints for AWS services"
  
  # Identity and Access Management
  identity:
    - "IAM roles with minimal permissions"
    - "Service accounts with IRSA"
    - "RBAC for Kubernetes resources"
    - "Pod security standards"
    - "Admission controllers"
  
  # Data Protection
  data:
    - "Encryption at rest (EBS, S3, EFS)"
    - "Encryption in transit (TLS)"
    - "Key management with AWS KMS"
    - "Data classification and labeling"
    - "Access logging and auditing"
  
  # Application Security
  application:
    - "Container image scanning"
    - "Runtime security monitoring"
    - "Secrets management"
    - "Input validation and sanitization"
    - "Output filtering and monitoring"
  
  # Monitoring and Response
  monitoring:
    - "Security event logging"
    - "Anomaly detection"
    - "Incident response automation"
    - "Compliance monitoring"
    - "Threat intelligence integration"
```

### Pattern 2: Zero Trust Architecture

```yaml
# Zero trust implementation for AI/ML
zero_trust_principles:
  # Never Trust, Always Verify
  verification:
    - "Mutual TLS for all communications"
    - "Certificate-based authentication"
    - "Continuous identity verification"
    - "Context-aware access decisions"
  
  # Least Privilege Access
  access_control:
    - "Just-in-time access provisioning"
    - "Attribute-based access control"
    - "Dynamic policy enforcement"
    - "Regular access reviews"
  
  # Assume Breach
  breach_assumption:
    - "Micro-segmentation"
    - "Lateral movement prevention"
    - "Continuous monitoring"
    - "Automated threat response"
```

## Network Security Implementation

### VPC and Subnet Design

```hcl
# Secure VPC architecture for AI/ML
resource "aws_vpc" "ml_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "ml-vpc"
    Environment = var.environment
  }
}

# Private subnets for ML workloads
resource "aws_subnet" "ml_private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.ml_vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "ml-private-${count.index + 1}"
    Type = "private"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Isolated subnets for sensitive workloads
resource "aws_subnet" "ml_isolated" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.ml_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "ml-isolated-${count.index + 1}"
    Type = "isolated"
  }
}

# Security groups with least privilege
resource "aws_security_group" "ml_training" {
  name_prefix = "ml-training-"
  vpc_id      = aws_vpc.ml_vpc.id
  
  # Allow inbound from same security group
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }
  
  # Allow outbound to AWS services
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS services"
  }
  
  # Allow outbound to container registries
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Container registry access"
  }
  
  tags = {
    Name = "ml-training-sg"
  }
}

resource "aws_security_group" "ml_inference" {
  name_prefix = "ml-inference-"
  vpc_id      = aws_vpc.ml_vpc.id
  
  # Allow inbound from ALB
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }
  
  # Allow outbound for model downloads
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Model downloads"
  }
  
  tags = {
    Name = "ml-inference-sg"
  }
}
```

### Network Policies

```yaml
# Kubernetes network policies for ML workloads
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
  
  # Allow from monitoring
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080  # Metrics endpoint
  
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
  
  # Allow communication within namespace
  - to:
    - namespaceSelector:
        matchLabels:
          name: ml-training
---
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
  
  # Allow from same namespace
  - from:
    - namespaceSelector:
        matchLabels:
          name: ml-inference
  
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
---
# Deny-all default policy
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
```

## Identity and Access Management

### RBAC Configuration

```yaml
# Role-based access control for ML teams
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ml-training
  name: ml-engineer
rules:
# Allow managing training jobs
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Allow managing pods for debugging
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "delete"]

# Allow managing config maps and secrets
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Allow managing PVCs
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "delete"]

# Read-only access to services and deployments
- apiGroups: ["", "apps"]
  resources: ["services", "deployments"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ml-inference
  name: ml-ops
rules:
# Full access to inference deployments
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["*"]

# Manage services and ingress
- apiGroups: ["", "networking.k8s.io"]
  resources: ["services", "ingresses"]
  verbs: ["*"]

# Manage HPA
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["*"]

# Read access to pods and logs
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
---
# Bind roles to users/groups
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ml-engineers
  namespace: ml-training
subjects:
- kind: Group
  name: ml-engineers
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

### Service Account Security

```yaml
# Service accounts with IRSA for AWS access
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
# IAM role for training workloads
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
        "arn:aws:s3:::ml-model-artifacts/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::ml-training-data",
        "arn:aws:s3:::ml-model-artifacts"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

## Pod Security Standards

### Pod Security Policies

```yaml
# Pod Security Standards enforcement
apiVersion: v1
kind: Namespace
metadata:
  name: ml-training
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-inference
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
# Security context for ML workloads
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-ml-training
  namespace: ml-training
spec:
  template:
    spec:
      serviceAccountName: ml-training-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: training
        image: ml-training:secure
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "16Gi"
            cpu: "8"
          requests:
            nvidia.com/gpu: 1
            memory: "8Gi"
            cpu: "4"
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
```

## Secrets Management

### External Secrets Operator

```yaml
# External Secrets Operator configuration
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
# External secret for model API keys
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: model-api-keys
  namespace: ml-training
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: model-api-keys
    creationPolicy: Owner
  data:
  - secretKey: openai-api-key
    remoteRef:
      key: ml/openai-api-key
  - secretKey: huggingface-token
    remoteRef:
      key: ml/huggingface-token
---
# Use secrets in deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-inference
spec:
  template:
    spec:
      containers:
      - name: inference
        image: ml-inference:latest
        env:
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: model-api-keys
              key: openai-api-key
        - name: HUGGINGFACE_TOKEN
          valueFrom:
            secretKeyRef:
              name: model-api-keys
              key: huggingface-token
```

## Container Security

### Image Scanning and Policies

```yaml
# OPA Gatekeeper policies for container security
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredsecuritycontext
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredSecurityContext
      validation:
        type: object
        properties:
          runAsNonRoot:
            type: boolean
          readOnlyRootFilesystem:
            type: boolean
          allowPrivilegeEscalation:
            type: boolean
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredsecuritycontext
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := "Container must run as non-root user"
        }
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.readOnlyRootFilesystem
          msg := "Container must have read-only root filesystem"
        }
        
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.allowPrivilegeEscalation
          msg := "Container must not allow privilege escalation"
        }
---
# Apply security context constraint
apiVersion: config.gatekeeper.sh/v1alpha1
kind: K8sRequiredSecurityContext
metadata:
  name: must-have-security-context
spec:
  match:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
      namespaces: ["ml-training", "ml-inference"]
  parameters:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
```

### Runtime Security

```yaml
# Falco rules for ML workload monitoring
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-ml-rules
data:
  ml_rules.yaml: |
    - rule: Suspicious Model File Access
      desc: Detect unauthorized access to model files
      condition: >
        open_read and
        fd.name contains "/models/" and
        not proc.name in (python, python3, pytorch, tensorflow)
      output: >
        Suspicious access to model files (user=%user.name command=%proc.cmdline
        file=%fd.name container=%container.name)
      priority: WARNING
      tags: [ml, model_security]
    
    - rule: Unexpected Network Connection from ML Pod
      desc: Detect unexpected network connections from ML workloads
      condition: >
        outbound and
        k8s.ns.name in (ml-training, ml-inference) and
        not fd.sip in (aws_metadata_service_ip, cluster_dns_ip) and
        not fd.sport in (80, 443, 53)
      output: >
        Unexpected network connection from ML pod (user=%user.name
        command=%proc.cmdline connection=%fd.name container=%container.name)
      priority: WARNING
      tags: [ml, network_security]
    
    - rule: Privilege Escalation in ML Container
      desc: Detect privilege escalation attempts in ML containers
      condition: >
        spawned_process and
        k8s.ns.name in (ml-training, ml-inference) and
        proc.name in (sudo, su, setuid_binaries)
      output: >
        Privilege escalation attempt in ML container (user=%user.name
        command=%proc.cmdline container=%container.name)
      priority: CRITICAL
      tags: [ml, privilege_escalation]
```

## Data Protection

### Encryption Configuration

```yaml
# Encryption at rest configuration
apiVersion: v1
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
---
# EFS with encryption
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-encrypted
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-12345678
  directoryPerms: "0755"
  encrypted: "true"
  kmsKeyId: <arn>
```

### Data Loss Prevention

```python
# Data sanitization for ML workloads
import re
import hashlib
from typing import Dict, List, Any

class MLDataSanitizer:
    def __init__(self):
        # PII patterns
        self.pii_patterns = {
            'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
            'phone': r'\b\d{3}-\d{3}-\d{4}\b|\b\(\d{3}\)\s*\d{3}-\d{4}\b',
            'ssn': r'\b\d{3}-\d{2}-\d{4}\b',
            'credit_card': r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
            'ip_address': r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'
        }
        
        # Sensitive keywords
        self.sensitive_keywords = [
            'password', 'secret', 'key', 'token', 'credential',
            'private', 'confidential', 'internal'
        ]
    
    def sanitize_training_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Sanitize training data to remove PII"""
        sanitized_data = {}
        
        for key, value in data.items():
            if isinstance(value, str):
                sanitized_data[key] = self._sanitize_text(value)
            elif isinstance(value, dict):
                sanitized_data[key] = self.sanitize_training_data(value)
            elif isinstance(value, list):
                sanitized_data[key] = [
                    self._sanitize_text(item) if isinstance(item, str) else item
                    for item in value
                ]
            else:
                sanitized_data[key] = value
        
        return sanitized_data
    
    def _sanitize_text(self, text: str) -> str:
        """Sanitize text by removing or masking PII"""
        sanitized = text
        
        # Replace PII patterns
        for pii_type, pattern in self.pii_patterns.items():
            sanitized = re.sub(pattern, f'[REDACTED_{pii_type.upper()}]', sanitized)
        
        # Hash sensitive values
        for keyword in self.sensitive_keywords:
            if keyword.lower() in sanitized.lower():
                # Replace with hash
                hash_value = hashlib.sha256(sanitized.encode()).hexdigest()[:8]
                sanitized = f'[HASHED_{hash_value}]'
                break
        
        return sanitized
    
    def validate_model_output(self, output: str) -> bool:
        """Validate that model output doesn't contain PII"""
        for pattern in self.pii_patterns.values():
            if re.search(pattern, output):
                return False
        return True
    
    def audit_data_access(self, user: str, data_path: str, action: str):
        """Audit data access for compliance"""
        audit_log = {
            'timestamp': datetime.utcnow().isoformat(),
            'user': user,
            'data_path': data_path,
            'action': action,
            'ip_address': self._get_client_ip()
        }
        
        # Log to secure audit system
        self._log_audit_event(audit_log)

# Usage in ML pipeline
sanitizer = MLDataSanitizer()

# Sanitize training data
clean_data = sanitizer.sanitize_training_data(raw_training_data)

# Validate model outputs
if not sanitizer.validate_model_output(model_response):
    raise SecurityError("Model output contains PII")
```

## Compliance and Auditing

### Audit Logging

```yaml
# Kubernetes audit policy
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log all requests to ML namespaces
- level: RequestResponse
  namespaces: ["ml-training", "ml-inference"]
  resources:
  - group: ""
    resources: ["pods", "services", "secrets", "configmaps"]
  - group: "apps"
    resources: ["deployments", "replicasets"]

# Log all secret access
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]

# Log all RBAC changes
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]

# Log admission controller decisions
- level: Request
  users: ["system:serviceaccount:gatekeeper-system:gatekeeper-admin"]
```

### Compliance Monitoring

```python
# Compliance monitoring for ML workloads
class ComplianceMonitor:
    def __init__(self):
        self.compliance_rules = {
            'gdpr': {
                'data_retention_days': 365,
                'requires_consent': True,
                'right_to_deletion': True
            },
            'hipaa': {
                'encryption_required': True,
                'access_logging': True,
                'minimum_necessary': True
            },
            'sox': {
                'change_management': True,
                'segregation_of_duties': True,
                'audit_trail': True
            }
        }
    
    def check_compliance(self, workload_config: Dict) -> Dict[str, bool]:
        """Check workload compliance against regulations"""
        compliance_status = {}
        
        for regulation, rules in self.compliance_rules.items():
            compliance_status[regulation] = self._check_regulation_compliance(
                workload_config, rules
            )
        
        return compliance_status
    
    def _check_regulation_compliance(self, config: Dict, rules: Dict) -> bool:
        """Check compliance against specific regulation"""
        for rule, requirement in rules.items():
            if rule == 'encryption_required' and requirement:
                if not config.get('encryption_enabled', False):
                    return False
            
            elif rule == 'access_logging' and requirement:
                if not config.get('audit_logging_enabled', False):
                    return False
            
            elif rule == 'data_retention_days':
                if config.get('retention_days', 0) > requirement:
                    return False
        
        return True
    
    def generate_compliance_report(self) -> Dict:
        """Generate compliance report for audit"""
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'cluster_compliance': self._check_cluster_compliance(),
            'workload_compliance': self._check_workload_compliance(),
            'recommendations': self._get_compliance_recommendations()
        }
```

## Security Decision Matrix

| Security Requirement | Basic | Enhanced | Enterprise |
|----------------------|-------|----------|------------|
| **Network Isolation** | Security Groups | + Network Policies | + Micro-segmentation |
| **Identity Management** | Basic RBAC | + IRSA | + External IdP |
| **Secrets Management** | K8s Secrets | + External Secrets | + HSM Integration |
| **Container Security** | Image Scanning | + Runtime Security | + Zero Trust |
| **Data Protection** | Encryption at Rest | + In-Transit | + Field-level |
| **Compliance** | Basic Logging | + Audit Trails | + Automated Compliance |
| **Incident Response** | Manual | + Automated Detection | + SOAR Integration |

## Next Steps

- Review [Operational Model Choices](09-operational-models.md) for secure operations
- Explore [Cost Optimization](10-cost-optimization.md) for security cost management
- Consider implementation guides in [How Section](../03-how/06-networking-security.md)

## Repository Examples

See security implementations:
- **Network Security**: [VPC and security group configurations](../../infra/base/terraform/vpc.tf)
- **RBAC Setup**: [Kubernetes RBAC examples](../../infra/base/kubernetes-addons/rbac)
- **Pod Security**: [Security context examples](../../blueprints/inference/vllm-rayserve-gpu)
