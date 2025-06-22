# Exercise 3: Multi-Model Serving Platform 🟡

**Objective**: Deploy multiple models with NVIDIA Triton Server, configure model versioning and A/B testing, and implement custom preprocessing.

**Difficulty**: Intermediate  
**Estimated Time**: 2-3 hours  
**Prerequisites**: Completed Exercise 1, understanding of model serving concepts

## What You'll Learn

- How to deploy NVIDIA Triton Server for multi-model serving
- Configure model repositories and versioning
- Implement A/B testing between model versions
- Set up custom preprocessing and postprocessing
- Monitor multi-model performance and resource usage
- Handle model loading and unloading dynamically

## Prerequisites

- EKS cluster with GPU nodes
- Completed [Exercise 1: Deploy Your First LLM](01-deploy-first-llm.md)
- kubectl configured to access your cluster
- Basic understanding of model serving concepts

## Step 1: Set Up Model Repository

First, let's create a structured model repository:

```bash
# Create namespace for multi-model serving
kubectl create namespace multi-model-serving

# Navigate to Triton blueprint
cd blueprints/inference/vllm-nvidia-triton-server-gpu
```

Create a model repository structure:

```bash
# Create local model repository structure
mkdir -p model-repository/{bert-base,gpt2-small,sentiment-classifier}/{1,2}

# Create model configurations
cat > model-repository/bert-base/config.pbtxt << 'EOF'
name: "bert-base"
platform: "pytorch_libtorch"
max_batch_size: 8
input [
  {
    name: "input_ids"
    data_type: TYPE_INT64
    dims: [ -1 ]
  },
  {
    name: "attention_mask"
    data_type: TYPE_INT64
    dims: [ -1 ]
  }
]
output [
  {
    name: "last_hidden_state"
    data_type: TYPE_FP32
    dims: [ -1, 768 ]
  }
]
version_policy: { all { }}
EOF

cat > model-repository/gpt2-small/config.pbtxt << 'EOF'
name: "gpt2-small"
platform: "python"
max_batch_size: 4
input [
  {
    name: "text_input"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }
]
output [
  {
    name: "generated_text"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }
]
version_policy: { all { }}
EOF

cat > model-repository/sentiment-classifier/config.pbtxt << 'EOF'
name: "sentiment-classifier"
platform: "pytorch_libtorch"
max_batch_size: 16
input [
  {
    name: "text_input"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }
]
output [
  {
    name: "sentiment_score"
    data_type: TYPE_FP32
    dims: [ -1, 2 ]
  },
  {
    name: "sentiment_label"
    data_type: TYPE_STRING
    dims: [ -1 ]
  }
]
version_policy: { all { }}
EOF
```

## Step 2: Create Model Implementations

### Python Backend for GPT-2

```python
# model-repository/gpt2-small/1/model.py
import json
import numpy as np
import triton_python_backend_utils as pb_utils
from transformers import GPT2LMHeadModel, GPT2Tokenizer
import torch

class TritonPythonModel:
    def initialize(self, args):
        """Initialize the model"""
        self.model_config = json.loads(args['model_config'])
        
        # Load GPT-2 model and tokenizer
        model_name = "gpt2"
        self.tokenizer = GPT2Tokenizer.from_pretrained(model_name)
        self.model = GPT2LMHeadModel.from_pretrained(model_name)
        
        # Set padding token
        self.tokenizer.pad_token = self.tokenizer.eos_token
        
        # Move to GPU if available
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model.to(self.device)
        self.model.eval()
        
        print(f"GPT-2 model loaded on {self.device}")
    
    def execute(self, requests):
        """Execute inference requests"""
        responses = []
        
        for request in requests:
            # Get input text
            input_text = pb_utils.get_input_tensor_by_name(request, "text_input")
            input_text = input_text.as_numpy().astype(str)
            
            batch_responses = []
            
            for text in input_text:
                try:
                    # Tokenize input
                    inputs = self.tokenizer.encode(text[0], return_tensors="pt")
                    inputs = inputs.to(self.device)
                    
                    # Generate text
                    with torch.no_grad():
                        outputs = self.model.generate(
                            inputs,
                            max_length=inputs.shape[1] + 50,
                            num_return_sequences=1,
                            temperature=0.7,
                            do_sample=True,
                            pad_token_id=self.tokenizer.eos_token_id
                        )
                    
                    # Decode generated text
                    generated_text = self.tokenizer.decode(
                        outputs[0], 
                        skip_special_tokens=True
                    )
                    
                    batch_responses.append(generated_text)
                    
                except Exception as e:
                    print(f"Error generating text: {e}")
                    batch_responses.append(f"Error: {str(e)}")
            
            # Create output tensor
            output_tensor = pb_utils.Tensor(
                "generated_text",
                np.array(batch_responses, dtype=object)
            )
            
            response = pb_utils.InferenceResponse(output_tensors=[output_tensor])
            responses.append(response)
        
        return responses
    
    def finalize(self):
        """Clean up resources"""
        print("GPT-2 model finalized")
```

### Sentiment Classifier Implementation

```python
# model-repository/sentiment-classifier/1/model.py
import json
import numpy as np
import triton_python_backend_utils as pb_utils
from transformers import pipeline
import torch

class TritonPythonModel:
    def initialize(self, args):
        """Initialize the sentiment classifier"""
        self.model_config = json.loads(args['model_config'])
        
        # Load sentiment analysis pipeline
        self.classifier = pipeline(
            "sentiment-analysis",
            model="cardiffnlp/twitter-roberta-base-sentiment-latest",
            device=0 if torch.cuda.is_available() else -1
        )
        
        print("Sentiment classifier loaded")
    
    def execute(self, requests):
        """Execute sentiment analysis requests"""
        responses = []
        
        for request in requests:
            # Get input text
            input_text = pb_utils.get_input_tensor_by_name(request, "text_input")
            input_text = input_text.as_numpy().astype(str)
            
            batch_scores = []
            batch_labels = []
            
            for text in input_text:
                try:
                    # Perform sentiment analysis
                    result = self.classifier(text[0])
                    
                    # Extract score and label
                    label = result[0]['label']
                    score = result[0]['score']
                    
                    # Convert to binary sentiment (positive/negative)
                    if label == 'LABEL_2':  # Positive
                        sentiment_scores = [1.0 - score, score]
                        sentiment_label = "positive"
                    else:  # Negative or Neutral
                        sentiment_scores = [score, 1.0 - score]
                        sentiment_label = "negative"
                    
                    batch_scores.append(sentiment_scores)
                    batch_labels.append(sentiment_label)
                    
                except Exception as e:
                    print(f"Error in sentiment analysis: {e}")
                    batch_scores.append([0.5, 0.5])
                    batch_labels.append("unknown")
            
            # Create output tensors
            score_tensor = pb_utils.Tensor(
                "sentiment_score",
                np.array(batch_scores, dtype=np.float32)
            )
            
            label_tensor = pb_utils.Tensor(
                "sentiment_label",
                np.array(batch_labels, dtype=object)
            )
            
            response = pb_utils.InferenceResponse(
                output_tensors=[score_tensor, label_tensor]
            )
            responses.append(response)
        
        return responses
    
    def finalize(self):
        """Clean up resources"""
        print("Sentiment classifier finalized")
```

## Step 3: Deploy Triton Server

Create a custom Triton deployment configuration:

```yaml
# triton-multi-model-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: triton-multi-model-server
  namespace: multi-model-serving
spec:
  replicas: 2
  selector:
    matchLabels:
      app: triton-multi-model-server
  template:
    metadata:
      labels:
        app: triton-multi-model-server
        component: model-server
    spec:
      nodeSelector:
        node-class: gpu
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      
      containers:
      - name: triton-server
        image: nvcr.io/nvidia/tritonserver:23.04-py3
        ports:
        - containerPort: 8000
          name: http
        - containerPort: 8001
          name: grpc
        - containerPort: 8002
          name: metrics
        
        args:
        - tritonserver
        - --model-repository=/models
        - --allow-http=true
        - --allow-grpc=true
        - --allow-metrics=true
        - --strict-model-config=false
        - --log-verbose=1
        
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
        - name: model-repository
          mountPath: /models
        - name: cache
          mountPath: /tmp
        
        livenessProbe:
          httpGet:
            path: /v2/health/live
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /v2/health/ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
        
        env:
        - name: CUDA_VISIBLE_DEVICES
          value: "0"
      
      volumes:
      - name: model-repository
        configMap:
          name: model-repository-config
      - name: cache
        emptyDir: {}
---
# Service for Triton server
apiVersion: v1
kind: Service
metadata:
  name: triton-multi-model-service
  namespace: multi-model-serving
  labels:
    app: triton-multi-model-server
spec:
  selector:
    app: triton-multi-model-server
  ports:
  - name: http
    port: 8000
    targetPort: 8000
  - name: grpc
    port: 8001
    targetPort: 8001
  - name: metrics
    port: 8002
    targetPort: 8002
  type: ClusterIP
---
# HPA for auto-scaling
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: triton-multi-model-hpa
  namespace: multi-model-serving
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: triton-multi-model-server
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

Create ConfigMap with model repository:

```bash
# Create ConfigMap with model configurations
kubectl create configmap model-repository-config \
  --from-file=model-repository/ \
  -n multi-model-serving

# Deploy Triton server
kubectl apply -f triton-multi-model-deployment.yaml

# Verify deployment
kubectl get pods -n multi-model-serving
kubectl logs -f deployment/triton-multi-model-server -n multi-model-serving
```

## Step 4: Implement A/B Testing

Create an A/B testing proxy:

```python
# ab-testing-proxy.py
from flask import Flask, request, jsonify
import requests
import random
import json
import time
from datetime import datetime

app = Flask(__name__)

# A/B testing configuration
AB_TEST_CONFIG = {
    'gpt2-small': {
        'version_1': {'weight': 70, 'endpoint': 'v2/models/gpt2-small/versions/1/infer'},
        'version_2': {'weight': 30, 'endpoint': 'v2/models/gpt2-small/versions/2/infer'}
    },
    'sentiment-classifier': {
        'version_1': {'weight': 50, 'endpoint': 'v2/models/sentiment-classifier/versions/1/infer'},
        'version_2': {'weight': 50, 'endpoint': 'v2/models/sentiment-classifier/versions/2/infer'}
    }
}

# Metrics storage (in production, use proper metrics backend)
METRICS = {
    'requests': {},
    'latency': {},
    'errors': {}
}

def select_model_version(model_name):
    """Select model version based on A/B testing weights"""
    if model_name not in AB_TEST_CONFIG:
        return None, None
    
    config = AB_TEST_CONFIG[model_name]
    rand_num = random.randint(1, 100)
    
    cumulative_weight = 0
    for version, version_config in config.items():
        cumulative_weight += version_config['weight']
        if rand_num <= cumulative_weight:
            return version, version_config['endpoint']
    
    # Fallback to first version
    first_version = list(config.keys())[0]
    return first_version, config[first_version]['endpoint']

def record_metrics(model_name, version, latency, success):
    """Record metrics for monitoring"""
    key = f"{model_name}_{version}"
    
    if key not in METRICS['requests']:
        METRICS['requests'][key] = 0
        METRICS['latency'][key] = []
        METRICS['errors'][key] = 0
    
    METRICS['requests'][key] += 1
    METRICS['latency'][key].append(latency)
    
    if not success:
        METRICS['errors'][key] += 1

@app.route('/v2/models/<model_name>/infer', methods=['POST'])
def proxy_inference(model_name):
    """Proxy inference requests with A/B testing"""
    
    # Select model version
    version, endpoint = select_model_version(model_name)
    if not endpoint:
        return jsonify({'error': f'Model {model_name} not configured for A/B testing'}), 400
    
    # Forward request to Triton server
    triton_url = f"http://triton-multi-model-service:8000/{endpoint}"
    
    start_time = time.time()
    success = True
    
    try:
        response = requests.post(
            triton_url,
            json=request.json,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        latency = time.time() - start_time
        
        if response.status_code == 200:
            result = response.json()
            # Add version info to response
            result['model_version'] = version
            result['ab_test_group'] = version
            
            record_metrics(model_name, version, latency, True)
            return jsonify(result)
        else:
            success = False
            record_metrics(model_name, version, latency, False)
            return jsonify({'error': 'Inference failed'}), response.status_code
            
    except Exception as e:
        latency = time.time() - start_time
        record_metrics(model_name, version, latency, False)
        return jsonify({'error': str(e)}), 500

@app.route('/metrics')
def get_metrics():
    """Get A/B testing metrics"""
    return jsonify(METRICS)

@app.route('/ab-config')
def get_ab_config():
    """Get current A/B testing configuration"""
    return jsonify(AB_TEST_CONFIG)

@app.route('/ab-config', methods=['POST'])
def update_ab_config():
    """Update A/B testing configuration"""
    global AB_TEST_CONFIG
    try:
        new_config = request.json
        AB_TEST_CONFIG.update(new_config)
        return jsonify({'status': 'updated', 'config': AB_TEST_CONFIG})
    except Exception as e:
        return jsonify({'error': str(e)}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
```

Deploy the A/B testing proxy:

```yaml
# ab-testing-proxy-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ab-testing-proxy
  namespace: multi-model-serving
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ab-testing-proxy
  template:
    metadata:
      labels:
        app: ab-testing-proxy
    spec:
      containers:
      - name: proxy
        image: python:3.9-slim
        ports:
        - containerPort: 8080
        command:
        - /bin/bash
        - -c
        - |
          pip install flask requests
          python /app/ab-testing-proxy.py
        volumeMounts:
        - name: proxy-code
          mountPath: /app
        resources:
          limits:
            memory: "1Gi"
            cpu: "1"
          requests:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: proxy-code
        configMap:
          name: ab-testing-proxy-code
---
apiVersion: v1
kind: Service
metadata:
  name: ab-testing-proxy-service
  namespace: multi-model-serving
spec:
  selector:
    app: ab-testing-proxy
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

## Step 5: Test Multi-Model Serving

Create test scripts to validate the setup:

```python
# test-multi-model-serving.py
import requests
import json
import time
import concurrent.futures
from typing import List, Dict

class MultiModelTester:
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.results = []
    
    def test_gpt2_generation(self, text_input: str) -> Dict:
        """Test GPT-2 text generation"""
        url = f"{self.base_url}/v2/models/gpt2-small/infer"
        
        payload = {
            "inputs": [
                {
                    "name": "text_input",
                    "shape": [1],
                    "datatype": "BYTES",
                    "data": [text_input]
                }
            ]
        }
        
        start_time = time.time()
        try:
            response = requests.post(url, json=payload, timeout=30)
            latency = time.time() - start_time
            
            if response.status_code == 200:
                result = response.json()
                return {
                    'model': 'gpt2-small',
                    'success': True,
                    'latency': latency,
                    'input': text_input,
                    'output': result.get('outputs', [{}])[0].get('data', [''])[0],
                    'version': result.get('model_version', 'unknown')
                }
            else:
                return {
                    'model': 'gpt2-small',
                    'success': False,
                    'latency': latency,
                    'error': response.text
                }
        except Exception as e:
            return {
                'model': 'gpt2-small',
                'success': False,
                'latency': time.time() - start_time,
                'error': str(e)
            }
    
    def test_sentiment_analysis(self, text_input: str) -> Dict:
        """Test sentiment analysis"""
        url = f"{self.base_url}/v2/models/sentiment-classifier/infer"
        
        payload = {
            "inputs": [
                {
                    "name": "text_input",
                    "shape": [1],
                    "datatype": "BYTES",
                    "data": [text_input]
                }
            ]
        }
        
        start_time = time.time()
        try:
            response = requests.post(url, json=payload, timeout=30)
            latency = time.time() - start_time
            
            if response.status_code == 200:
                result = response.json()
                outputs = result.get('outputs', [])
                
                sentiment_score = outputs[0].get('data', [0.5, 0.5]) if outputs else [0.5, 0.5]
                sentiment_label = outputs[1].get('data', ['unknown'])[0] if len(outputs) > 1 else 'unknown'
                
                return {
                    'model': 'sentiment-classifier',
                    'success': True,
                    'latency': latency,
                    'input': text_input,
                    'sentiment_score': sentiment_score,
                    'sentiment_label': sentiment_label,
                    'version': result.get('model_version', 'unknown')
                }
            else:
                return {
                    'model': 'sentiment-classifier',
                    'success': False,
                    'latency': latency,
                    'error': response.text
                }
        except Exception as e:
            return {
                'model': 'sentiment-classifier',
                'success': False,
                'latency': time.time() - start_time,
                'error': str(e)
            }
    
    def run_load_test(self, num_requests: int = 50, concurrency: int = 10):
        """Run load test on multiple models"""
        
        test_inputs = [
            "This is a great day for machine learning!",
            "I'm feeling sad about the weather today.",
            "The new AI model performs exceptionally well.",
            "This product is terrible and disappointing.",
            "Machine learning is revolutionizing technology."
        ]
        
        def run_single_test(i):
            text = test_inputs[i % len(test_inputs)]
            
            # Randomly choose between models
            if i % 2 == 0:
                return self.test_gpt2_generation(text)
            else:
                return self.test_sentiment_analysis(text)
        
        print(f"Starting load test with {num_requests} requests and {concurrency} concurrent workers...")
        
        start_time = time.time()
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
            futures = [executor.submit(run_single_test, i) for i in range(num_requests)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # Analyze results
        successful_requests = [r for r in results if r['success']]
        failed_requests = [r for r in results if not r['success']]
        
        avg_latency = sum(r['latency'] for r in successful_requests) / len(successful_requests) if successful_requests else 0
        
        # Group by model and version
        model_stats = {}
        for result in successful_requests:
            model = result['model']
            version = result.get('version', 'unknown')
            key = f"{model}_{version}"
            
            if key not in model_stats:
                model_stats[key] = {'count': 0, 'total_latency': 0}
            
            model_stats[key]['count'] += 1
            model_stats[key]['total_latency'] += result['latency']
        
        print(f"\n=== Load Test Results ===")
        print(f"Total time: {total_time:.2f} seconds")
        print(f"Requests per second: {num_requests / total_time:.2f}")
        print(f"Successful requests: {len(successful_requests)}")
        print(f"Failed requests: {len(failed_requests)}")
        print(f"Average latency: {avg_latency:.3f} seconds")
        
        print(f"\n=== Model Version Distribution ===")
        for key, stats in model_stats.items():
            avg_latency = stats['total_latency'] / stats['count']
            print(f"{key}: {stats['count']} requests, avg latency: {avg_latency:.3f}s")
        
        if failed_requests:
            print(f"\n=== Failed Requests ===")
            for req in failed_requests[:5]:  # Show first 5 failures
                print(f"Model: {req['model']}, Error: {req.get('error', 'Unknown')}")
        
        return results

# Usage
if __name__ == "__main__":
    # Test with A/B testing proxy
    tester = MultiModelTester("http://localhost:8080")
    
    # Run load test
    results = tester.run_load_test(num_requests=100, concurrency=10)
```

Run the tests:

```bash
# Port forward to access the A/B testing proxy
kubectl port-forward -n multi-model-serving svc/ab-testing-proxy-service 8080:8080 &

# Run the test
python test-multi-model-serving.py
```

## Verification Checklist

Verify your multi-model serving setup:

- [ ] Triton server is running and healthy
- [ ] Multiple models are loaded and accessible
- [ ] A/B testing proxy is routing requests correctly
- [ ] Model versions are being distributed according to weights
- [ ] Metrics are being collected for each model version
- [ ] Autoscaling is working based on load
- [ ] All models respond within acceptable latency limits

## Challenge Tasks 🔴

### Challenge 1: Dynamic Model Management
Implement dynamic model loading and unloading:
1. Create API endpoints to load/unload models without restarting Triton
2. Implement model warming strategies
3. Add model health checks and automatic recovery
4. Monitor model memory usage and optimize allocation

### Challenge 2: Advanced A/B Testing
Enhance the A/B testing system:
1. Implement user-based routing (sticky sessions)
2. Add statistical significance testing
3. Implement automatic traffic shifting based on performance
4. Add canary deployment capabilities

### Challenge 3: Model Registry Integration
Build a complete model registry:
1. Integrate with MLflow or similar model registry
2. Implement model versioning and metadata tracking
3. Add model approval workflows
4. Implement automated model deployment pipelines

### Challenge 4: Performance Optimization
Optimize multi-model serving performance:
1. Implement model batching across different models
2. Add GPU memory sharing between models
3. Implement intelligent model placement
4. Add request queuing and prioritization

## Troubleshooting

### Common Issues

**Models not loading:**
```bash
# Check Triton server logs
kubectl logs -f deployment/triton-multi-model-server -n multi-model-serving

# Verify model repository structure
kubectl exec -it deployment/triton-multi-model-server -n multi-model-serving -- ls -la /models

# Check model configurations
kubectl exec -it deployment/triton-multi-model-server -n multi-model-serving -- cat /models/gpt2-small/config.pbtxt
```

**A/B testing not working:**
```bash
# Check proxy logs
kubectl logs -f deployment/ab-testing-proxy -n multi-model-serving

# Test direct Triton access
kubectl port-forward -n multi-model-serving svc/triton-multi-model-service 8000:8000
curl http://localhost:8000/v2/health/ready
```

**High latency or errors:**
```bash
# Check resource usage
kubectl top pods -n multi-model-serving

# Monitor GPU usage
kubectl exec -it deployment/triton-multi-model-server -n multi-model-serving -- nvidia-smi

# Check HPA status
kubectl get hpa -n multi-model-serving
```

## Clean Up

When you're done with the exercise:

```bash
# Stop port forwarding
pkill -f "kubectl port-forward"

# Delete the deployment
kubectl delete namespace multi-model-serving

# Verify cleanup
kubectl get all -n multi-model-serving
```

## Next Steps

Congratulations! You've successfully set up a multi-model serving platform. Next, try:

1. **[Exercise 4: Cost Optimization Challenge](04-cost-optimization.md)** - Optimize costs while maintaining performance
2. **[Exercise 5: Production Monitoring Setup](05-production-monitoring.md)** - Set up comprehensive monitoring
3. **[Exercise 9: MLOps Pipeline](09-mlops-pipeline.md)** - Build end-to-end MLOps workflows

## Key Takeaways

- NVIDIA Triton Server provides excellent multi-model serving capabilities
- A/B testing enables safe model deployment and comparison
- Proper model repository structure is crucial for management
- Dynamic model loading allows for flexible resource utilization
- Monitoring and metrics are essential for production deployments
- Custom preprocessing can be implemented using Python backends

## Share Your Results

Share your experience with the community:
- Post your A/B testing results and insights
- Share custom model implementations
- Contribute improvements to the Triton blueprints
- Help others with multi-model serving challenges
