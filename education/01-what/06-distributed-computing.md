# Distributed Computing Frameworks

## What is Distributed Computing for AI/ML?

Distributed computing frameworks enable AI/ML workloads to scale beyond the capacity of a single machine by coordinating work across multiple nodes. These frameworks are essential for training large models and serving high-throughput inference workloads on Amazon EKS.

## Why Distributed Computing is Essential for AI/ML

1. **Model Size**: Modern AI models often exceed the memory capacity of a single GPU
2. **Data Volume**: Training datasets can be too large to process on a single machine
3. **Computation Speed**: Distributing work reduces training and inference time
4. **High Availability**: Distributed systems provide redundancy and fault tolerance
5. **Scalability**: Ability to scale resources based on workload demands

## Ray: A Comprehensive Framework for Distributed Computing

[Ray](https://www.ray.io/) is an open-source unified framework for scaling AI and Python applications. It's particularly well-suited for AI/ML workloads on Kubernetes.

### Key Components of Ray

1. **Ray Core**: Provides the distributed execution framework
2. **Ray Train**: For distributed model training
3. **Ray Tune**: For hyperparameter tuning
4. **Ray Serve**: For model serving and inference
5. **Ray Data**: For distributed data processing
6. **Ray RLlib**: For reinforcement learning

### Ray Architecture

![Ray Architecture](https://docs.ray.io/en/latest/_images/ray-architecture.png)

- **Ray Head**: Coordinates the cluster and schedules tasks
- **Ray Workers**: Execute tasks and store objects
- **Object Store**: Distributed memory for sharing data between tasks
- **GCS (Global Control Store)**: Maintains cluster state information

### Ray on EKS: KubeRay

[KubeRay](https://ray-project.github.io/kuberay/) is a Kubernetes operator that simplifies deploying and managing Ray clusters on Kubernetes.

```yaml
apiVersion: ray.io/v1
kind: RayCluster
metadata:
  name: ray-cluster
spec:
  headGroupSpec:
    rayStartParams:
      dashboard-host: "0.0.0.0"
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray:2.9.0
          resources:
            limits:
              cpu: "2"
              memory: "8Gi"
  workerGroupSpecs:
  - groupName: gpu-group
    replicas: 3
    rayStartParams: {}
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray:2.9.0
          resources:
            limits:
              cpu: "4"
              memory: "16Gi"
              nvidia.com/gpu: "1"
```

## Other Distributed Computing Frameworks for AI/ML

### PyTorch Distributed

Native distributed training support in PyTorch.

**Key Features:**
- **DDP (DistributedDataParallel)**: Data parallel training
- **FSDP (FullyShardedDataParallel)**: Memory-efficient distributed training
- **RPC Framework**: For general distributed computing
- **Collective Communications**: Efficient multi-GPU operations

### Horovod

A distributed deep learning training framework originally developed by Uber.

**Key Features:**
- **Framework Agnostic**: Works with TensorFlow, PyTorch, and MXNet
- **Ring-AllReduce**: Efficient algorithm for gradient aggregation
- **Easy Integration**: Minimal code changes to existing models
- **MPI Integration**: Leverages MPI for communication

### Dask

A flexible parallel computing library for analytics.

**Key Features:**
- **Familiar API**: Similar to NumPy, Pandas, and scikit-learn
- **Dynamic Task Scheduling**: Adapts to available resources
- **Data Locality**: Minimizes data movement
- **Integration with ML Frameworks**: Works with scikit-learn, XGBoost, etc.

### TensorFlow Distributed

TensorFlow's built-in distributed training capabilities.

**Key Features:**
- **Distribution Strategies**: High-level API for distributed training
- **Parameter Server Architecture**: For large-scale distributed training
- **tf.distribute**: Simplified API for distribution
- **Keras Integration**: Works with high-level Keras API

## Distributed Computing Patterns

### Data Parallelism

Splits the data across multiple workers, each with a complete copy of the model.

- **Pros**: Simple to implement, scales well with data size
- **Cons**: Limited by model size (must fit in each worker's memory)
- **Use Case**: Training medium-sized models on large datasets

### Model Parallelism

Splits the model across multiple workers, each processing the complete dataset.

- **Pros**: Can handle very large models
- **Cons**: More complex, potential communication overhead
- **Use Case**: Training very large models (100B+ parameters)

### Pipeline Parallelism

Splits the model into stages that run on different workers in a pipeline fashion.

- **Pros**: Balances computation and communication
- **Cons**: Complex implementation, potential pipeline bubbles
- **Use Case**: Training large models with sequential components

### Tensor Parallelism

Splits individual operations across multiple devices.

- **Pros**: Efficient for large matrix operations
- **Cons**: Requires specialized implementation
- **Use Case**: Very large transformer models

## Considerations for EKS Deployment

1. **Network Performance**: Use instance types with enhanced networking (EFA)
2. **Node Placement**: Consider node affinity to ensure related processes are co-located
3. **Resource Allocation**: Properly size CPU, memory, and GPU resources
4. **Storage Access**: Configure fast access to shared storage
5. **Monitoring**: Set up monitoring for distributed workloads
6. **Fault Tolerance**: Implement checkpointing and recovery mechanisms

## Next Steps

- Learn about [Storage Solutions for AI/ML](07-storage-solutions.md)
- Explore [Hardware Options](08-hardware-options.md) for distributed computing

## Repository Examples

This repository demonstrates various distributed computing patterns for AI/ML workloads:

**Ray and KubeRay:**
- **Ray Cluster Setup**: See [Ray infrastructure examples](../../infra/ray) for setting up Ray clusters on EKS
- **Distributed Training**: Check [Ray training blueprints](../../blueprints/training/ray) for distributed model training
- **Ray Serve**: Explore [Ray serving examples](../../blueprints/inference/ray-serve) for scalable inference
- **JARK Stack**: Review the [JARK stack implementation](../../infra/jark-stack) (Jupyter, Argo, Ray, Kubeflow)

**PyTorch Distributed:**
- **DDP Training**: See examples of DistributedDataParallel training on EKS
- **FSDP Examples**: Check FullyShardedDataParallel implementations for large models
- **Multi-Node Training**: Examples of training across multiple GPU nodes

**Horovod:**
- **Multi-Framework Training**: Examples using Horovod with PyTorch and TensorFlow
- **MPI Integration**: Configurations for high-performance networking

**Kubeflow:**
- **Training Operators**: See [Kubeflow examples](../../infra/kubeflow) for managed distributed training
- **Pipeline Integration**: Examples of ML pipelines with distributed components

**Learn More:**
- [Ray Documentation](https://docs.ray.io/)
- [KubeRay Documentation](https://ray-project.github.io/kuberay/)
- [PyTorch Distributed](https://pytorch.org/tutorials/beginner/dist_overview.html)
- [Horovod Documentation](https://horovod.readthedocs.io/)
- [Kubeflow Training Operator](https://www.kubeflow.org/docs/components/training/)
