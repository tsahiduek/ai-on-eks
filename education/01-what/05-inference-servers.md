# Inference Servers

## What is an Inference Server?

An inference server is a specialized software application that exposes trained AI models through standardized APIs, handling request management, scaling, and monitoring. It acts as the interface between client applications and the underlying model execution, which is typically handled by inference backends (like vLLM, TensorRT-LLM, or PyTorch) that perform the actual model computations.

## Why Inference Servers Are Essential

Even when using powerful inference backends like vLLM, inference servers provide critical capabilities:

1. **API Standardization**: Provide consistent REST/gRPC APIs regardless of the underlying backend
2. **Request Management**: Handle authentication, rate limiting, and request routing
3. **Multi-Model Serving**: Serve multiple models simultaneously with resource sharing
4. **Production Features**: Logging, monitoring, health checks, and graceful shutdowns
5. **Client Abstraction**: Shield clients from backend-specific implementations and changes
6. **Load Balancing**: Distribute requests across multiple model instances or backends
7. **Version Management**: Support A/B testing and gradual model rollouts
8. **Resource Orchestration**: Manage when to load/unload models based on demand

Think of inference backends as the "engine" that runs the model, while inference servers are the "vehicle" that makes the engine accessible and manageable in production environments.

## Key Functions of Inference Servers

1. **API Exposure**: Provides HTTP/gRPC endpoints for model access
2. **Request Handling**: Manages incoming requests and queuing
3. **Load Balancing**: Distributes requests across multiple model instances
4. **Model Management**: Handles model loading, unloading, and versioning
5. **Batching**: Combines multiple requests for efficient processing
6. **Monitoring**: Collects metrics on throughput, latency, and resource usage
7. **Resource Optimization**: Manages GPU memory and compute resources

## Popular Inference Servers

### Ray Serve

Part of the Ray ecosystem, designed for scalable model serving with Python-first approach.

**Key Features:**
- **Python-First**: Native Python API for easy integration
- **Dynamic Scaling**: Scales based on load automatically
- **Composition**: Easy composition of models and business logic
- **Stateful Serving**: Supports stateful applications
- **Integration with Ray Ecosystem**: Works seamlessly with Ray's distributed computing capabilities

**Best For:**
- Python-centric workflows
- Integration with Ray for training and serving
- Complex serving pipelines with business logic

**Documentation**: [Ray Serve Documentation](https://docs.ray.io/en/latest/serve/index.html)

### NVIDIA Triton Inference Server

A high-performance inference serving system designed to deploy AI models from any framework on any GPU or CPU-based infrastructure.

**Key Features:**
- **Multi-Framework Support**: TensorFlow, PyTorch, ONNX, TensorRT, and custom backends
- **Dynamic Batching**: Combines inference requests for higher throughput
- **Concurrent Model Execution**: Runs multiple models on the same GPU
- **Model Ensemble**: Chains multiple models in a single request
- **Model Versioning**: Supports multiple versions of the same model
- **Metrics**: Prometheus integration for monitoring
- **Kubernetes Integration**: Native support for Kubernetes deployments

**Best For:**
- Production deployments requiring high performance
- Environments with models from multiple frameworks
- Complex inference pipelines

**Documentation**: [NVIDIA Triton Documentation](https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/index.html)

### vLLM Serving

A serving layer built on top of the vLLM inference library, specialized for LLMs.

**Key Features:**
- **OpenAI-compatible API**: Drop-in replacement for OpenAI's API
- **Streaming Support**: Efficient token streaming for chat applications
- **PagedAttention**: Memory-efficient attention mechanism
- **Continuous Batching**: Processes requests as they arrive
- **Multi-GPU Support**: Distributes models across multiple GPUs

**Best For:**
- Large language models
- OpenAI API compatibility requirements
- High-throughput LLM applications

**Documentation**: [vLLM Documentation](https://docs.vllm.ai/)

### KServe (formerly KFServing)

A Kubernetes-native inference platform built on Knative.

**Key Features:**
- **Serverless**: Scales to zero when not in use
- **Multi-Framework**: Supports various ML frameworks
- **Canary Deployments**: Traffic splitting for model updates
- **Explainability**: Built-in support for model explanations
- **Transformers**: Pre/post-processing components

**Best For:**
- Kubernetes-native environments
- Serverless inference requirements
- Complex deployment patterns (canary, A/B testing)

**Documentation**: [KServe Documentation](https://kserve.github.io/website/latest/)

### TorchServe

PyTorch's native solution for serving deep learning models.

**Key Features:**
- **PyTorch Optimized**: Native support for PyTorch models
- **Model Management API**: REST API for model management
- **Custom Handlers**: Extensible pre/post-processing
- **Metrics**: Prometheus integration
- **Multi-Model Serving**: Hosts multiple models in a single server

**Best For:**
- PyTorch-based models
- Research environments moving to production
- Simpler deployment scenarios

**Documentation**: [TorchServe Documentation](https://pytorch.org/serve/)

## Comparison of Inference Servers

| Server | Framework Support | Batching Capabilities | Scaling | Kubernetes Integration | Complexity |
|--------|-------------------|----------------------|---------|------------------------|------------|
| NVIDIA Triton | Multiple frameworks | Advanced dynamic batching | Horizontal | Excellent | Medium-High |
| vLLM Serving | PyTorch (LLMs) | Continuous batching | Horizontal | Good | Medium |
| TorchServe | PyTorch | Basic batching | Horizontal | Good | Low-Medium |
| KServe | Multiple frameworks | Framework-dependent | Serverless | Excellent | Medium-High |
| Ray Serve | Python frameworks | Custom batching | Elastic | Good | Medium |

## Deployment Patterns on EKS

### Standalone Deployment

Running the inference server directly as a Kubernetes deployment.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: triton-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: triton-server
  template:
    metadata:
      labels:
        app: triton-server
    spec:
      containers:
      - name: triton
        image: nvcr.io/nvidia/tritonserver:23.04-py3
        resources:
          limits:
            nvidia.com/gpu: 1
```

### Operator-Based Deployment

Using Kubernetes operators for advanced management.

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llm-service
spec:
  predictor:
    model:
      modelFormat:
        name: pytorch
      storageUri: s3://my-bucket/models/llm
      resources:
        limits:
          nvidia.com/gpu: 1
```

### Helm-Based Deployment

Using Helm charts for configurable deployments.

```bash
helm install triton-inference-server nvidia/triton-inference-server \
  --set image.tag=23.04-py3 \
  --set modelRepositoryPath=s3://my-bucket/models
```

## Considerations for EKS Deployment

1. **Resource Allocation**: Properly size CPU, memory, and GPU resources
2. **Autoscaling**: Configure HPA based on GPU utilization or custom metrics
3. **Networking**: Set appropriate timeouts for long-running inference requests
4. **Storage**: Configure fast access to model storage (FSx, EFS, S3)
5. **Security**: Implement proper authentication and network policies
6. **Monitoring**: Set up Prometheus and Grafana for observability

## Next Steps

- Learn about [Distributed Computing Frameworks](06-distributed-computing.md) for scaling inference
- Explore [Storage Solutions for AI/ML](07-storage-solutions.md) to store and access models

## Repository Examples

This repository provides comprehensive examples of deploying various inference servers on EKS:

**NVIDIA Triton Server:**
- **Complete Infrastructure**: See [Triton server infrastructure](../../infra/nvidia-triton-server) with Terraform and Kubernetes manifests
- **Multi-Model Serving**: Examples of serving multiple models simultaneously
- **Dynamic Batching**: Configurations for optimizing throughput
- **Model Repository**: Patterns for organizing and accessing models

**vLLM Serving:**
- **LLM Deployment**: Check [vLLM blueprints](../../blueprints/inference/vllm) for serving large language models
- **OpenAI API Compatibility**: Examples of OpenAI-compatible endpoints
- **Multi-GPU Configurations**: Tensor parallelism examples

**KServe Deployments:**
- **Serverless Inference**: See [KServe examples](../../blueprints/inference/kserve) for auto-scaling inference
- **Canary Deployments**: Traffic splitting examples for model updates
- **Custom Predictors**: Examples of custom inference logic

**Ray Serve:**
- **Distributed Serving**: Check [Ray serving examples](../../blueprints/inference/ray-serve) for scalable inference
- **Business Logic Integration**: Examples combining models with application logic

**TorchServe:**
- **PyTorch Models**: See examples for serving PyTorch models with TorchServe
- **Custom Handlers**: Examples of preprocessing and postprocessing

**Learn More:**
- [NVIDIA Triton Documentation](https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/index.html)
- [vLLM Documentation](https://docs.vllm.ai/)
- [KServe Documentation](https://kserve.github.io/website/latest/)
- [Ray Serve Documentation](https://docs.ray.io/en/latest/serve/index.html)
- [TorchServe Documentation](https://pytorch.org/serve/)
