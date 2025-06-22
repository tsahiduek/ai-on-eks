# Observability and Monitoring Choices

## The Decision

How should you design your observability strategy to effectively monitor, debug, and optimize AI/ML workloads on EKS while balancing cost, complexity, and operational overhead?

## Observability Requirements for AI/ML

### Unique Monitoring Challenges

#### AI/ML Specific Metrics
- **Model Performance**: Accuracy, precision, recall, F1-score
- **Inference Latency**: P50, P95, P99 response times
- **GPU Utilization**: Memory usage, compute utilization, temperature
- **Training Progress**: Loss curves, learning rates, epoch times
- **Data Quality**: Data drift, feature distribution changes
- **Resource Efficiency**: Cost per inference, training job efficiency

#### Scale and Complexity
- **High Cardinality**: Many models, versions, experiments
- **Dynamic Workloads**: Auto-scaling inference, batch training jobs
- **Multi-Tenant**: Different teams, projects, cost centers
- **Distributed Systems**: Multi-node training, model serving clusters

## Monitoring Stack Options

### Option 1: Prometheus + Grafana (Open Source)

#### When to Choose Prometheus/Grafana

**Advantages:**
- **Cost-Effective**: Open source with no licensing fees
- **Kubernetes Native**: Excellent integration with K8s ecosystem
- **Flexible**: Highly customizable dashboards and alerting
- **Community**: Large ecosystem of exporters and dashboards
- **Data Retention Control**: Full control over data retention policies

**Disadvantages:**
- **Operational Overhead**: Requires management and maintenance
- **Scaling Challenges**: Single-node limitations for large deployments
- **Limited Long-term Storage**: Requires additional solutions for long-term retention
- **Query Performance**: Can be slow for complex queries over large datasets

#### Implementation Architecture

```yaml
# Prometheus configuration for AI/ML workloads
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "/etc/prometheus/rules/*.yml"
    
    scrape_configs:
    # Kubernetes API server
    - job_name: 'kubernetes-apiservers'
      kubernetes_sd_configs:
      - role: endpoints
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https
    
    # Node metrics
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
    
    # GPU metrics
    - job_name: 'gpu-metrics'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
    
    # AI/ML application metrics
    - job_name: 'ml-applications'
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_label_app_type]
        action: keep
        regex: ml-.*
    
    # Training job metrics
    - job_name: 'training-jobs'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_job_type]
        action: keep
        regex: training
    
    # Model serving metrics
    - job_name: 'model-serving'
      kubernetes_sd_configs:
      - role: service
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_label_component]
        action: keep
        regex: model-server
    
    alerting:
      alertmanagers:
      - static_configs:
        - targets:
          - alertmanager:9093
```

#### Custom AI/ML Metrics Collection

```python
# ml_metrics_exporter.py
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import time
import threading
import torch
import psutil
import GPUtil

class MLMetricsExporter:
    def __init__(self, port=8000):
        # Model performance metrics
        self.inference_requests = Counter('ml_inference_requests_total', 
                                        'Total inference requests', 
                                        ['model_name', 'model_version', 'status'])
        
        self.inference_duration = Histogram('ml_inference_duration_seconds',
                                          'Inference request duration',
                                          ['model_name', 'model_version'])
        
        self.model_accuracy = Gauge('ml_model_accuracy',
                                  'Model accuracy score',
                                  ['model_name', 'model_version', 'dataset'])
        
        # Training metrics
        self.training_loss = Gauge('ml_training_loss',
                                 'Training loss value',
                                 ['job_name', 'epoch'])
        
        self.training_accuracy = Gauge('ml_training_accuracy',
                                     'Training accuracy',
                                     ['job_name', 'epoch'])
        
        self.learning_rate = Gauge('ml_learning_rate',
                                 'Current learning rate',
                                 ['job_name'])
        
        # Resource utilization
        self.gpu_utilization = Gauge('ml_gpu_utilization_percent',
                                   'GPU utilization percentage',
                                   ['gpu_id', 'gpu_name'])
        
        self.gpu_memory_used = Gauge('ml_gpu_memory_used_bytes',
                                   'GPU memory used in bytes',
                                   ['gpu_id', 'gpu_name'])
        
        self.gpu_memory_total = Gauge('ml_gpu_memory_total_bytes',
                                    'GPU memory total in bytes',
                                    ['gpu_id', 'gpu_name'])
        
        # Data quality metrics
        self.data_drift_score = Gauge('ml_data_drift_score',
                                    'Data drift detection score',
                                    ['feature_name', 'model_name'])
        
        self.feature_importance = Gauge('ml_feature_importance',
                                      'Feature importance score',
                                      ['feature_name', 'model_name'])
        
        # Cost metrics
        self.inference_cost = Counter('ml_inference_cost_dollars',
                                    'Cost per inference in dollars',
                                    ['model_name', 'instance_type'])
        
        self.training_cost = Gauge('ml_training_cost_dollars',
                                 'Training job cost in dollars',
                                 ['job_name', 'instance_type'])
        
        # Start metrics server
        start_http_server(port)
        
        # Start background collection
        self.start_background_collection()
    
    def record_inference(self, model_name, model_version, duration, status='success'):
        """Record inference request metrics"""
        self.inference_requests.labels(
            model_name=model_name,
            model_version=model_version,
            status=status
        ).inc()
        
        self.inference_duration.labels(
            model_name=model_name,
            model_version=model_version
        ).observe(duration)
    
    def record_training_metrics(self, job_name, epoch, loss, accuracy, lr):
        """Record training progress metrics"""
        self.training_loss.labels(job_name=job_name, epoch=epoch).set(loss)
        self.training_accuracy.labels(job_name=job_name, epoch=epoch).set(accuracy)
        self.learning_rate.labels(job_name=job_name).set(lr)
    
    def start_background_collection(self):
        """Start background thread for system metrics collection"""
        def collect_system_metrics():
            while True:
                try:
                    # Collect GPU metrics
                    if torch.cuda.is_available():
                        for i in range(torch.cuda.device_count()):
                            gpu = GPUtil.getGPUs()[i]
                            
                            self.gpu_utilization.labels(
                                gpu_id=str(i),
                                gpu_name=gpu.name
                            ).set(gpu.load * 100)
                            
                            self.gpu_memory_used.labels(
                                gpu_id=str(i),
                                gpu_name=gpu.name
                            ).set(gpu.memoryUsed * 1024 * 1024)  # Convert to bytes
                            
                            self.gpu_memory_total.labels(
                                gpu_id=str(i),
                                gpu_name=gpu.name
                            ).set(gpu.memoryTotal * 1024 * 1024)  # Convert to bytes
                    
                    time.sleep(15)  # Collect every 15 seconds
                    
                except Exception as e:
                    print(f"Error collecting system metrics: {e}")
                    time.sleep(60)  # Wait longer on error
        
        thread = threading.Thread(target=collect_system_metrics, daemon=True)
        thread.start()

# Usage in ML applications
metrics_exporter = MLMetricsExporter(port=8000)

# In inference code
start_time = time.time()
result = model.predict(input_data)
duration = time.time() - start_time

metrics_exporter.record_inference(
    model_name="llama-7b",
    model_version="v1.0",
    duration=duration,
    status="success"
)

# In training code
for epoch in range(num_epochs):
    loss, accuracy = train_epoch()
    lr = optimizer.param_groups[0]['lr']
    
    metrics_exporter.record_training_metrics(
        job_name="llama-training",
        epoch=epoch,
        loss=loss,
        accuracy=accuracy,
        lr=lr
    )
```

### Option 2: Amazon CloudWatch

#### When to Choose CloudWatch

**Advantages:**
- **Fully Managed**: No infrastructure to maintain
- **AWS Integration**: Native integration with AWS services
- **Scalable**: Handles large volumes of metrics automatically
- **Alerting**: Built-in alerting with SNS integration
- **Cost Predictable**: Pay-per-use pricing model

**Disadvantages:**
- **Cost**: Can become expensive with high metric volumes
- **Limited Customization**: Less flexible than open-source solutions
- **Vendor Lock-in**: Tied to AWS ecosystem
- **Query Limitations**: Limited query capabilities compared to PromQL

#### CloudWatch Implementation

```yaml
# CloudWatch agent configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: cwagentconfig
  namespace: amazon-cloudwatch
data:
  cwagentconfig.json: |
    {
      "agent": {
        "region": "us-west-2"
      },
      "logs": {
        "metrics_collected": {
          "kubernetes": {
            "cluster_name": "ai-ml-cluster",
            "metrics_collection_interval": 60
          }
        },
        "force_flush_interval": 15
      },
      "metrics": {
        "namespace": "AI/ML/EKS",
        "metrics_collected": {
          "cpu": {
            "measurement": ["cpu_usage_idle", "cpu_usage_iowait"],
            "metrics_collection_interval": 60
          },
          "disk": {
            "measurement": ["used_percent"],
            "metrics_collection_interval": 60,
            "resources": ["*"]
          },
          "diskio": {
            "measurement": ["io_time", "read_bytes", "write_bytes"],
            "metrics_collection_interval": 60,
            "resources": ["*"]
          },
          "mem": {
            "measurement": ["mem_used_percent"],
            "metrics_collection_interval": 60
          },
          "netstat": {
            "measurement": ["tcp_established", "tcp_time_wait"],
            "metrics_collection_interval": 60
          },
          "swap": {
            "measurement": ["swap_used_percent"],
            "metrics_collection_interval": 60
          }
        }
      }
    }
```

### Option 3: Hybrid Approach

#### Best of Both Worlds Strategy

```yaml
# Hybrid monitoring architecture
monitoring_strategy:
  # Real-time operational metrics
  prometheus_grafana:
    use_cases:
      - "Real-time dashboards"
      - "Alerting and incident response"
      - "Development and debugging"
    retention: "30 days"
    cost: "Low (infrastructure only)"
  
  # Long-term storage and compliance
  cloudwatch:
    use_cases:
      - "Long-term trend analysis"
      - "Compliance and audit logs"
      - "Cross-service correlation"
    retention: "1 year+"
    cost: "Medium (pay per use)"
  
  # Data pipeline
  data_flow:
    - "Prometheus scrapes metrics"
    - "Grafana for real-time visualization"
    - "CloudWatch for long-term storage"
    - "Custom exporters bridge the gap"
```

## Alerting Strategy Decisions

### Alert Fatigue Prevention

```yaml
# Intelligent alerting configuration
alerting_rules:
  # Critical alerts (immediate response)
  critical:
    - name: "ModelServingDown"
      condition: "up{job='model-serving'} == 0"
      for: "1m"
      severity: "critical"
      runbook: "https://wiki.company.com/model-serving-down"
    
    - name: "HighInferenceLatency"
      condition: "ml_inference_duration_seconds{quantile='0.95'} > 5"
      for: "2m"
      severity: "critical"
      
    - name: "GPUOutOfMemory"
      condition: "ml_gpu_memory_used_bytes / ml_gpu_memory_total_bytes > 0.95"
      for: "30s"
      severity: "critical"
  
  # Warning alerts (investigation needed)
  warning:
    - name: "ModelAccuracyDegraded"
      condition: "ml_model_accuracy < 0.85"
      for: "5m"
      severity: "warning"
      
    - name: "HighErrorRate"
      condition: "rate(ml_inference_requests_total{status='error'}[5m]) / rate(ml_inference_requests_total[5m]) > 0.05"
      for: "3m"
      severity: "warning"
  
  # Info alerts (awareness)
  info:
    - name: "TrainingJobCompleted"
      condition: "increase(ml_training_epochs_total[1h]) > 0"
      severity: "info"
      notification_channels: ["slack"]

# Alert routing
alert_routing:
  critical:
    - "pagerduty"
    - "slack-critical"
    - "email-oncall"
  warning:
    - "slack-warnings"
    - "email-team"
  info:
    - "slack-general"
```

### Intelligent Alert Grouping

```python
# Smart alert aggregation
class AlertManager:
    def __init__(self):
        self.alert_groups = {}
        self.suppression_rules = {}
    
    def process_alert(self, alert):
        """Process incoming alert with intelligent grouping"""
        
        # Group related alerts
        group_key = self.get_group_key(alert)
        
        if group_key not in self.alert_groups:
            self.alert_groups[group_key] = {
                'alerts': [],
                'first_seen': time.time(),
                'last_updated': time.time(),
                'severity': alert['severity']
            }
        
        # Add to group
        self.alert_groups[group_key]['alerts'].append(alert)
        self.alert_groups[group_key]['last_updated'] = time.time()
        
        # Update severity if higher
        if self.get_severity_level(alert['severity']) > self.get_severity_level(self.alert_groups[group_key]['severity']):
            self.alert_groups[group_key]['severity'] = alert['severity']
        
        # Check if should send notification
        if self.should_notify(group_key):
            self.send_grouped_notification(group_key)
    
    def get_group_key(self, alert):
        """Generate grouping key for related alerts"""
        # Group by service and alert type
        return f"{alert.get('service', 'unknown')}:{alert.get('alertname', 'unknown')}"
    
    def should_notify(self, group_key):
        """Determine if notification should be sent"""
        group = self.alert_groups[group_key]
        
        # Send immediately for critical alerts
        if group['severity'] == 'critical':
            return True
        
        # Batch non-critical alerts
        time_since_first = time.time() - group['first_seen']
        alert_count = len(group['alerts'])
        
        # Send if enough time passed or enough alerts accumulated
        return time_since_first > 300 or alert_count >= 5  # 5 minutes or 5 alerts
```

## Logging Strategy

### Centralized Logging Architecture

```yaml
# ELK Stack deployment for AI/ML logs
logging_architecture:
  # Log collection
  fluent_bit:
    deployment: "DaemonSet on all nodes"
    config:
      - "Collect container logs"
      - "Parse JSON logs"
      - "Add Kubernetes metadata"
      - "Filter sensitive data"
    
  # Log processing and storage
  elasticsearch:
    deployment: "StatefulSet with persistent storage"
    indices:
      - "ml-training-logs-*"
      - "ml-inference-logs-*"
      - "ml-system-logs-*"
    retention: "90 days"
    
  # Log visualization
  kibana:
    dashboards:
      - "Training job logs"
      - "Inference request logs"
      - "Error analysis"
      - "Performance debugging"
```

### Structured Logging for AI/ML

```python
# Structured logging for ML applications
import structlog
import json
from datetime import datetime

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

class MLLogger:
    def __init__(self, service_name, model_name=None, version=None):
        self.logger = logger.bind(
            service=service_name,
            model_name=model_name,
            model_version=version
        )
    
    def log_inference_request(self, request_id, input_shape, processing_time, result):
        """Log inference request with structured data"""
        self.logger.info(
            "inference_request_completed",
            request_id=request_id,
            input_shape=input_shape,
            processing_time_ms=processing_time * 1000,
            result_shape=result.shape if hasattr(result, 'shape') else None,
            timestamp=datetime.utcnow().isoformat()
        )
    
    def log_training_progress(self, epoch, batch, loss, accuracy, lr):
        """Log training progress"""
        self.logger.info(
            "training_progress",
            epoch=epoch,
            batch=batch,
            loss=float(loss),
            accuracy=float(accuracy),
            learning_rate=float(lr),
            timestamp=datetime.utcnow().isoformat()
        )
    
    def log_model_load(self, model_path, load_time, memory_usage):
        """Log model loading events"""
        self.logger.info(
            "model_loaded",
            model_path=model_path,
            load_time_seconds=load_time,
            memory_usage_mb=memory_usage,
            timestamp=datetime.utcnow().isoformat()
        )
    
    def log_error(self, error_type, error_message, context=None):
        """Log errors with context"""
        self.logger.error(
            "error_occurred",
            error_type=error_type,
            error_message=str(error_message),
            context=context or {},
            timestamp=datetime.utcnow().isoformat()
        )

# Usage in ML applications
ml_logger = MLLogger("llm-inference", "llama-7b", "v1.0")

# Log inference
start_time = time.time()
result = model.predict(input_data)
processing_time = time.time() - start_time

ml_logger.log_inference_request(
    request_id="req-12345",
    input_shape=input_data.shape,
    processing_time=processing_time,
    result=result
)
```

## Cost Monitoring and Optimization

### FinOps for AI/ML Monitoring

```python
# Cost monitoring for AI/ML workloads
class MLCostMonitor:
    def __init__(self):
        self.cost_metrics = {
            'training_cost_per_hour': Gauge('ml_training_cost_per_hour_dollars'),
            'inference_cost_per_request': Gauge('ml_inference_cost_per_request_dollars'),
            'storage_cost_per_gb': Gauge('ml_storage_cost_per_gb_dollars'),
            'total_monthly_cost': Gauge('ml_total_monthly_cost_dollars')
        }
        
        self.instance_costs = {
            'p3.2xlarge': 3.06,
            'p3.8xlarge': 12.24,
            'g4dn.xlarge': 0.526,
            'g4dn.2xlarge': 0.752,
            'inf2.xlarge': 0.76
        }
    
    def calculate_training_cost(self, instance_type, duration_hours, num_instances=1):
        """Calculate training job cost"""
        hourly_cost = self.instance_costs.get(instance_type, 0)
        total_cost = hourly_cost * duration_hours * num_instances
        
        self.cost_metrics['training_cost_per_hour'].set(hourly_cost * num_instances)
        
        return total_cost
    
    def calculate_inference_cost(self, instance_type, requests_per_hour, utilization=0.7):
        """Calculate inference cost per request"""
        hourly_cost = self.instance_costs.get(instance_type, 0)
        effective_requests = requests_per_hour * utilization
        cost_per_request = hourly_cost / effective_requests if effective_requests > 0 else 0
        
        self.cost_metrics['inference_cost_per_request'].set(cost_per_request)
        
        return cost_per_request
    
    def generate_cost_report(self, time_period='monthly'):
        """Generate cost optimization recommendations"""
        recommendations = []
        
        # Analyze GPU utilization
        avg_gpu_util = self.get_average_gpu_utilization()
        if avg_gpu_util < 0.6:
            recommendations.append({
                'type': 'right_sizing',
                'message': f'GPU utilization is {avg_gpu_util:.1%}. Consider smaller instances.',
                'potential_savings': '20-40%'
            })
        
        # Analyze inference patterns
        peak_rps = self.get_peak_requests_per_second()
        avg_rps = self.get_average_requests_per_second()
        
        if peak_rps / avg_rps > 3:
            recommendations.append({
                'type': 'autoscaling',
                'message': 'High variance in request patterns. Implement autoscaling.',
                'potential_savings': '30-50%'
            })
        
        return recommendations
```

## Observability Decision Matrix

| Requirement | Prometheus/Grafana | CloudWatch | Hybrid | Commercial APM |
|-------------|-------------------|------------|---------|----------------|
| **Cost** | Low | Medium | Medium | High |
| **Customization** | High | Medium | High | Medium |
| **Operational Overhead** | High | Low | Medium | Low |
| **Kubernetes Integration** | Excellent | Good | Excellent | Good |
| **Long-term Storage** | Limited | Excellent | Excellent | Excellent |
| **Query Performance** | Good | Fair | Good | Excellent |
| **Alerting** | Excellent | Good | Excellent | Excellent |
| **Vendor Lock-in** | None | AWS | Partial | High |

## Implementation Recommendations

### For Startups/Small Teams
```yaml
recommended_stack:
  monitoring: "Prometheus + Grafana"
  logging: "ELK Stack (self-hosted)"
  alerting: "Slack integration"
  cost: "Manual tracking"
  rationale: "Cost-effective, full control"
```

### For Medium Organizations
```yaml
recommended_stack:
  monitoring: "Hybrid (Prometheus + CloudWatch)"
  logging: "CloudWatch Logs"
  alerting: "PagerDuty + Slack"
  cost: "AWS Cost Explorer + custom dashboards"
  rationale: "Balance of cost and features"
```

### For Large Enterprises
```yaml
recommended_stack:
  monitoring: "Commercial APM + Prometheus"
  logging: "Splunk or ELK Stack"
  alerting: "ServiceNow + PagerDuty"
  cost: "FinOps platform"
  rationale: "Enterprise features, compliance"
```

## Next Steps

- Review [Security Architecture Decisions](08-security-architecture.md) for comprehensive security monitoring
- Explore [Operational Model Choices](09-operational-models.md) for GitOps and automation
- Consider [Cost Optimization Strategies](10-cost-optimization.md) for monitoring cost management

## Repository Examples

See observability implementations:
- **Prometheus Setup**: [Monitoring infrastructure](../../infra/base/kubernetes-addons/prometheus)
- **Grafana Dashboards**: [AI/ML specific dashboards](../../infra/base/kubernetes-addons/grafana)
- **Custom Metrics**: [Application monitoring examples](../../blueprints/inference/vllm-rayserve-gpu)
