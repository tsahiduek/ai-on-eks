# Operational Model Choices

## The Decision

How should you structure your operational model to efficiently manage AI/ML workloads on EKS while ensuring reliability, security, and developer productivity?

## Operational Model Options

### Traditional Operations Model

#### Characteristics
- **Manual Deployments**: Human-driven deployment processes
- **Imperative Management**: Direct kubectl commands and manual configurations
- **Centralized Control**: Operations team manages all infrastructure changes
- **Reactive Monitoring**: Issue response after problems occur

#### When to Choose Traditional Operations
- **Small Teams**: Less than 5 developers
- **Simple Workloads**: Single application or model
- **Learning Phase**: Team is new to Kubernetes and AI/ML
- **Tight Control**: Regulatory requirements for manual approval

```yaml
# Traditional deployment approach
traditional_workflow:
  development:
    - "Developer writes code locally"
    - "Manual testing on development cluster"
    - "Create deployment YAML manually"
  
  deployment:
    - "Operations team reviews changes"
    - "Manual kubectl apply commands"
    - "Manual verification of deployment"
    - "Manual rollback if issues occur"
  
  monitoring:
    - "Manual log checking"
    - "Reactive alerting"
    - "Manual scaling decisions"
```

### GitOps Model

#### Characteristics
- **Declarative Configuration**: Infrastructure and applications as code
- **Git as Source of Truth**: All changes tracked in version control
- **Automated Synchronization**: Continuous deployment from Git repositories
- **Pull-based Deployment**: Cluster pulls changes rather than external push

#### GitOps Implementation with ArgoCD

```yaml
# ArgoCD application for ML workloads
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ml-training-platform
  namespace: argocd
spec:
  project: ml-platform
  source:
    repoURL: https://github.com/company/ml-platform-config
    targetRevision: main
    path: training/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: ml-training
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
---
# Application for inference workloads
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ml-inference-platform
  namespace: argocd
spec:
  project: ml-platform
  source:
    repoURL: https://github.com/company/ml-platform-config
    targetRevision: main
    path: inference/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: ml-inference
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas  # Ignore HPA-managed replicas
```

#### Repository Structure for GitOps

```
ml-platform-config/
├── applications/
│   ├── training/
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── configmap.yaml
│   │   └── overlays/
│   │       ├── development/
│   │       ├── staging/
│   │       └── production/
│   └── inference/
│       ├── base/
│       └── overlays/
├── infrastructure/
│   ├── namespaces/
│   ├── rbac/
│   ├── network-policies/
│   └── storage-classes/
└── monitoring/
    ├── prometheus/
    ├── grafana/
    └── alertmanager/
```

### Platform Engineering Model

#### Characteristics
- **Self-Service Platforms**: Developers can deploy independently
- **Standardized Templates**: Reusable deployment patterns
- **Automated Governance**: Policy enforcement through code
- **Developer Experience Focus**: Simplified interfaces for complex operations

#### Platform Implementation

```yaml
# Platform abstraction for ML workloads
apiVersion: v1
kind: ConfigMap
metadata:
  name: ml-platform-templates
data:
  training-job-template.yaml: |
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: "{{ .Values.jobName }}"
      namespace: "{{ .Values.namespace }}"
      labels:
        platform.company.com/managed: "true"
        platform.company.com/type: "training"
    spec:
      template:
        spec:
          serviceAccountName: "{{ .Values.serviceAccount }}"
          nodeSelector:
            node-class: "{{ .Values.nodeClass }}"
          tolerations:
          - key: "{{ .Values.taintKey }}"
            operator: Exists
            effect: NoSchedule
          containers:
          - name: training
            image: "{{ .Values.image }}"
            resources:
              limits:
                nvidia.com/gpu: "{{ .Values.gpuCount }}"
                memory: "{{ .Values.memory }}"
                cpu: "{{ .Values.cpu }}"
            env:
            - name: TRAINING_DATA_PATH
              value: "{{ .Values.dataPath }}"
            - name: MODEL_OUTPUT_PATH
              value: "{{ .Values.outputPath }}"
            volumeMounts:
            - name: data-volume
              mountPath: /data
            - name: output-volume
              mountPath: /output
          volumes:
          - name: data-volume
            persistentVolumeClaim:
              claimName: "{{ .Values.dataPVC }}"
          - name: output-volume
            persistentVolumeClaim:
              claimName: "{{ .Values.outputPVC }}"
          restartPolicy: Never
  
  inference-deployment-template.yaml: |
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: "{{ .Values.deploymentName }}"
      namespace: "{{ .Values.namespace }}"
      labels:
        platform.company.com/managed: "true"
        platform.company.com/type: "inference"
    spec:
      replicas: "{{ .Values.replicas }}"
      selector:
        matchLabels:
          app: "{{ .Values.deploymentName }}"
      template:
        metadata:
          labels:
            app: "{{ .Values.deploymentName }}"
        spec:
          serviceAccountName: "{{ .Values.serviceAccount }}"
          containers:
          - name: inference
            image: "{{ .Values.image }}"
            ports:
            - containerPort: 8080
            resources:
              limits:
                nvidia.com/gpu: "{{ .Values.gpuCount }}"
                memory: "{{ .Values.memory }}"
              requests:
                nvidia.com/gpu: "{{ .Values.gpuCount }}"
                memory: "{{ .Values.memoryRequest }}"
            env:
            - name: MODEL_PATH
              value: "{{ .Values.modelPath }}"
            - name: MAX_BATCH_SIZE
              value: "{{ .Values.maxBatchSize }}"
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
```

#### Self-Service Portal

```python
# Platform API for self-service ML deployments
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from kubernetes import client, config
import yaml
import jinja2
from typing import Dict, Any

app = FastAPI(title="ML Platform API")

class TrainingJobRequest(BaseModel):
    job_name: str
    image: str
    gpu_count: int
    memory: str
    cpu: str
    data_path: str
    output_path: str
    node_class: str = "gpu"

class InferenceDeploymentRequest(BaseModel):
    deployment_name: str
    image: str
    model_path: str
    replicas: int = 1
    gpu_count: int = 1
    memory: str = "8Gi"
    max_batch_size: int = 32

class MLPlatformAPI:
    def __init__(self):
        config.load_incluster_config()
        self.k8s_client = client.ApiClient()
        self.batch_api = client.BatchV1Api()
        self.apps_api = client.AppsV1Api()
        self.core_api = client.CoreV1Api()
        
        # Load templates
        with open('/templates/training-job-template.yaml', 'r') as f:
            self.training_template = jinja2.Template(f.read())
        
        with open('/templates/inference-deployment-template.yaml', 'r') as f:
            self.inference_template = jinja2.Template(f.read())
    
    def create_training_job(self, request: TrainingJobRequest, namespace: str = "ml-training"):
        """Create a training job using platform template"""
        
        # Validate request
        if not self._validate_training_request(request):
            raise HTTPException(status_code=400, detail="Invalid training request")
        
        # Render template
        job_yaml = self.training_template.render(
            Values={
                'jobName': request.job_name,
                'namespace': namespace,
                'image': request.image,
                'gpuCount': request.gpu_count,
                'memory': request.memory,
                'cpu': request.cpu,
                'dataPath': request.data_path,
                'outputPath': request.output_path,
                'nodeClass': request.node_class,
                'serviceAccount': 'ml-training-sa',
                'taintKey': 'nvidia.com/gpu',
                'dataPVC': f"{request.job_name}-data",
                'outputPVC': f"{request.job_name}-output"
            }
        )
        
        # Create Kubernetes job
        job_manifest = yaml.safe_load(job_yaml)
        
        try:
            # Create PVCs first
            self._create_training_pvcs(request.job_name, namespace)
            
            # Create job
            response = self.batch_api.create_namespaced_job(
                namespace=namespace,
                body=job_manifest
            )
            
            return {
                "status": "created",
                "job_name": request.job_name,
                "namespace": namespace,
                "uid": response.metadata.uid
            }
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to create job: {str(e)}")
    
    def create_inference_deployment(self, request: InferenceDeploymentRequest, namespace: str = "ml-inference"):
        """Create an inference deployment using platform template"""
        
        # Validate request
        if not self._validate_inference_request(request):
            raise HTTPException(status_code=400, detail="Invalid inference request")
        
        # Render template
        deployment_yaml = self.inference_template.render(
            Values={
                'deploymentName': request.deployment_name,
                'namespace': namespace,
                'image': request.image,
                'replicas': request.replicas,
                'gpuCount': request.gpu_count,
                'memory': request.memory,
                'memoryRequest': str(int(request.memory.rstrip('Gi')) // 2) + 'Gi',
                'modelPath': request.model_path,
                'maxBatchSize': request.max_batch_size,
                'serviceAccount': 'ml-inference-sa'
            }
        )
        
        # Create Kubernetes deployment
        deployment_manifest = yaml.safe_load(deployment_yaml)
        
        try:
            response = self.apps_api.create_namespaced_deployment(
                namespace=namespace,
                body=deployment_manifest
            )
            
            # Create service
            self._create_inference_service(request.deployment_name, namespace)
            
            return {
                "status": "created",
                "deployment_name": request.deployment_name,
                "namespace": namespace,
                "uid": response.metadata.uid
            }
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to create deployment: {str(e)}")
    
    def _validate_training_request(self, request: TrainingJobRequest) -> bool:
        """Validate training job request against platform policies"""
        
        # Check resource limits
        if request.gpu_count > 8:
            return False
        
        # Check memory limits
        memory_gb = int(request.memory.rstrip('Gi'))
        if memory_gb > 128:
            return False
        
        # Check image registry
        if not request.image.startswith('your-registry.com/'):
            return False
        
        return True
    
    def _validate_inference_request(self, request: InferenceDeploymentRequest) -> bool:
        """Validate inference deployment request against platform policies"""
        
        # Check replica limits
        if request.replicas > 20:
            return False
        
        # Check resource limits
        if request.gpu_count > 2:
            return False
        
        return True

platform_api = MLPlatformAPI()

@app.post("/api/v1/training-jobs")
async def create_training_job(request: TrainingJobRequest):
    return platform_api.create_training_job(request)

@app.post("/api/v1/inference-deployments")
async def create_inference_deployment(request: InferenceDeploymentRequest):
    return platform_api.create_inference_deployment(request)

@app.get("/api/v1/training-jobs/{namespace}")
async def list_training_jobs(namespace: str):
    jobs = platform_api.batch_api.list_namespaced_job(namespace=namespace)
    return {
        "jobs": [
            {
                "name": job.metadata.name,
                "status": job.status.conditions[-1].type if job.status.conditions else "Unknown",
                "created": job.metadata.creation_timestamp.isoformat()
            }
            for job in jobs.items
        ]
    }
```

## CI/CD Pipeline Strategies

### Model-Centric CI/CD

```yaml
# GitHub Actions workflow for ML model deployment
name: ML Model CI/CD
on:
  push:
    paths:
    - 'models/**'
    - 'training/**'
  pull_request:
    paths:
    - 'models/**'
    - 'training/**'

jobs:
  model-validation:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: |
        pip install -r requirements.txt
        pip install pytest pytest-cov
    
    - name: Run model tests
      run: |
        pytest tests/model_tests.py -v --cov=models
    
    - name: Validate model performance
      run: |
        python scripts/validate_model_performance.py
    
    - name: Check for data drift
      run: |
        python scripts/check_data_drift.py
    
    - name: Security scan
      run: |
        bandit -r models/ training/
        safety check
  
  build-and-push:
    needs: model-validation
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build and push training image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        ECR_REPOSITORY: ml-training
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -f training/Dockerfile .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
    
    - name: Build and push inference image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        ECR_REPOSITORY: ml-inference
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -f inference/Dockerfile .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
  
  deploy-staging:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: staging
    steps:
    - uses: actions/checkout@v3
    
    - name: Update staging manifests
      run: |
        sed -i "s|image: .*|image: ${{ steps.login-ecr.outputs.registry }}/ml-inference:${{ github.sha }}|" \
          k8s/staging/inference-deployment.yaml
    
    - name: Commit updated manifests
      run: |
        git config --local user.email "action@github.com"
        git config --local user.name "GitHub Action"
        git add k8s/staging/
        git commit -m "Update staging deployment to ${{ github.sha }}"
        git push origin main
  
  integration-tests:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Run integration tests
      run: |
        python tests/integration_tests.py --environment=staging
    
    - name: Performance benchmarks
      run: |
        python tests/performance_tests.py --environment=staging
  
  deploy-production:
    needs: integration-tests
    runs-on: ubuntu-latest
    environment: production
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    
    - name: Update production manifests
      run: |
        sed -i "s|image: .*|image: ${{ steps.login-ecr.outputs.registry }}/ml-inference:${{ github.sha }}|" \
          k8s/production/inference-deployment.yaml
    
    - name: Create pull request for production
      uses: peter-evans/create-pull-request@v5
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
        commit-message: "Deploy ${{ github.sha }} to production"
        title: "Production deployment: ${{ github.sha }}"
        body: |
          Automated production deployment
          
          - Commit: ${{ github.sha }}
          - Staging tests: ✅ Passed
          - Performance tests: ✅ Passed
        branch: deploy-production-${{ github.sha }}
```

## Environment Management Strategies

### Multi-Environment Architecture

```yaml
# Environment-specific configurations
environments:
  development:
    cluster: "dev-cluster"
    namespace: "ml-dev"
    resources:
      cpu_limit: "2"
      memory_limit: "4Gi"
      gpu_limit: 1
    replicas: 1
    monitoring: basic
    
  staging:
    cluster: "staging-cluster"
    namespace: "ml-staging"
    resources:
      cpu_limit: "4"
      memory_limit: "8Gi"
      gpu_limit: 1
    replicas: 2
    monitoring: enhanced
    
  production:
    cluster: "prod-cluster"
    namespace: "ml-prod"
    resources:
      cpu_limit: "8"
      memory_limit: "16Gi"
      gpu_limit: 2
    replicas: 3
    monitoring: comprehensive
    sla: "99.9%"
```

### Progressive Delivery

```yaml
# Argo Rollouts for ML model deployments
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: ml-model-rollout
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 20
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 10m}
      - setWeight: 100
      canaryService: ml-model-canary
      stableService: ml-model-stable
      analysis:
        templates:
        - templateName: model-performance-analysis
        args:
        - name: service-name
          value: ml-model-canary
        - name: baseline-service
          value: ml-model-stable
  selector:
    matchLabels:
      app: ml-model
  template:
    metadata:
      labels:
        app: ml-model
    spec:
      containers:
      - name: model-server
        image: ml-model:latest
        ports:
        - containerPort: 8080
---
# Analysis template for model performance
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: model-performance-analysis
spec:
  args:
  - name: service-name
  - name: baseline-service
  metrics:
  - name: accuracy
    interval: 60s
    count: 5
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          ml_model_accuracy{service="{{args.service-name}}"}
  
  - name: latency
    interval: 60s
    count: 5
    successCondition: result[0] <= 500
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          histogram_quantile(0.95, 
            rate(http_request_duration_seconds_bucket{service="{{args.service-name}}"}[2m])
          ) * 1000
  
  - name: error_rate
    interval: 60s
    count: 5
    successCondition: result[0] <= 0.01
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          rate(http_requests_total{service="{{args.service-name}}",status=~"5.."}[2m]) /
          rate(http_requests_total{service="{{args.service-name}}"}[2m])
```

## Disaster Recovery and Business Continuity

### Multi-Region Strategy

```yaml
# Multi-region deployment strategy
disaster_recovery:
  primary_region: "us-west-2"
  secondary_region: "us-east-1"
  
  replication:
    models: "Cross-region S3 replication"
    data: "Cross-region backup"
    configs: "GitOps repository mirroring"
  
  failover:
    rto: "15 minutes"  # Recovery Time Objective
    rpo: "5 minutes"   # Recovery Point Objective
    automation: "Automated with manual approval"
  
  testing:
    frequency: "Monthly"
    scope: "Full disaster recovery simulation"
```

### Backup and Recovery Automation

```python
# Automated backup and recovery system
import boto3
import kubernetes
from datetime import datetime, timedelta
import json

class MLDisasterRecovery:
    def __init__(self, primary_region='us-west-2', secondary_region='us-east-1'):
        self.primary_region = primary_region
        self.secondary_region = secondary_region
        
        # AWS clients
        self.s3_primary = boto3.client('s3', region_name=primary_region)
        self.s3_secondary = boto3.client('s3', region_name=secondary_region)
        
        # Kubernetes clients
        kubernetes.config.load_incluster_config()
        self.k8s_client = kubernetes.client.ApiClient()
    
    def backup_model_artifacts(self, source_bucket, dest_bucket):
        """Backup model artifacts to secondary region"""
        
        # List objects in source bucket
        paginator = self.s3_primary.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=source_bucket, Prefix='models/')
        
        for page in pages:
            if 'Contents' in page:
                for obj in page['Contents']:
                    key = obj['Key']
                    
                    # Copy to secondary region
                    copy_source = {'Bucket': source_bucket, 'Key': key}
                    self.s3_secondary.copy_object(
                        CopySource=copy_source,
                        Bucket=dest_bucket,
                        Key=key
                    )
                    
                    print(f"Backed up: {key}")
    
    def backup_kubernetes_configs(self, namespace):
        """Backup Kubernetes configurations"""
        
        backup_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'namespace': namespace,
            'resources': {}
        }
        
        # Backup deployments
        apps_api = kubernetes.client.AppsV1Api()
        deployments = apps_api.list_namespaced_deployment(namespace=namespace)
        backup_data['resources']['deployments'] = [
            self.k8s_client.sanitize_for_serialization(dep)
            for dep in deployments.items
        ]
        
        # Backup services
        core_api = kubernetes.client.CoreV1Api()
        services = core_api.list_namespaced_service(namespace=namespace)
        backup_data['resources']['services'] = [
            self.k8s_client.sanitize_for_serialization(svc)
            for svc in services.items
        ]
        
        # Backup configmaps
        configmaps = core_api.list_namespaced_config_map(namespace=namespace)
        backup_data['resources']['configmaps'] = [
            self.k8s_client.sanitize_for_serialization(cm)
            for cm in configmaps.items
        ]
        
        # Store backup in S3
        backup_key = f"k8s-backups/{namespace}/{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}.json"
        self.s3_secondary.put_object(
            Bucket='ml-disaster-recovery',
            Key=backup_key,
            Body=json.dumps(backup_data, indent=2)
        )
        
        return backup_key
    
    def test_failover(self):
        """Test disaster recovery failover process"""
        
        test_results = {
            'timestamp': datetime.utcnow().isoformat(),
            'tests': []
        }
        
        # Test 1: Verify secondary region accessibility
        try:
            self.s3_secondary.head_bucket(Bucket='ml-disaster-recovery')
            test_results['tests'].append({
                'name': 'Secondary region access',
                'status': 'PASS',
                'message': 'Successfully accessed secondary region'
            })
        except Exception as e:
            test_results['tests'].append({
                'name': 'Secondary region access',
                'status': 'FAIL',
                'message': str(e)
            })
        
        # Test 2: Verify model artifacts backup
        try:
            response = self.s3_secondary.list_objects_v2(
                Bucket='ml-disaster-recovery',
                Prefix='models/',
                MaxKeys=1
            )
            if 'Contents' in response:
                test_results['tests'].append({
                    'name': 'Model artifacts backup',
                    'status': 'PASS',
                    'message': 'Model artifacts found in secondary region'
                })
            else:
                test_results['tests'].append({
                    'name': 'Model artifacts backup',
                    'status': 'FAIL',
                    'message': 'No model artifacts found in secondary region'
                })
        except Exception as e:
            test_results['tests'].append({
                'name': 'Model artifacts backup',
                'status': 'FAIL',
                'message': str(e)
            })
        
        return test_results
```

## Operational Model Decision Matrix

| Factor | Traditional | GitOps | Platform Engineering |
|--------|-------------|--------|---------------------|
| **Team Size** | 1-5 | 5-50 | 20+ |
| **Complexity** | Low | Medium | High |
| **Automation** | Manual | High | Very High |
| **Developer Experience** | Poor | Good | Excellent |
| **Operational Overhead** | High | Medium | Low |
| **Compliance** | Manual | Good | Excellent |
| **Scalability** | Poor | Good | Excellent |
| **Time to Market** | Slow | Fast | Very Fast |

## Next Steps

- Review [Cost Optimization Strategies](10-cost-optimization.md) for operational cost management
- Explore implementation guides in [How Section](../03-how/08-cicd-setup.md)
- Consider [Hands-on Exercises](../04-hands-on/09-mlops-pipeline.md) for practical experience

## Repository Examples

See operational model implementations:
- **GitOps Setup**: [ArgoCD configurations](../../infra/base/kubernetes-addons/argocd)
- **CI/CD Pipelines**: [GitHub Actions workflows](../../.github/workflows)
- **Platform Templates**: [Helm charts and templates](../../blueprints)
