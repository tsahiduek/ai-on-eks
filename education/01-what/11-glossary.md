# Glossary: AI/ML Terms for Infrastructure Engineers

This glossary provides clear definitions of AI/ML terms that are important for DevOps engineers, solutions architects, and CTOs working with AI workloads on EKS. Terms are explained with a focus on infrastructure implications rather than mathematical details.

## A

**Accelerator**
Hardware designed to speed up specific computations. In AI/ML, this typically refers to GPUs, TPUs, or custom chips like AWS Trainium/Inferentia.
*Infrastructure Impact*: Requires specialized instance types and drivers.

**Attention Mechanism**
A technique that allows models to focus on different parts of the input when generating output. Critical component of transformer models.
*Infrastructure Impact*: Memory usage scales quadratically with sequence length, affecting GPU memory requirements.

**Auto-scaling**
Automatically adjusting the number of compute resources based on demand.
*Infrastructure Impact*: Essential for cost-effective inference serving; requires proper metrics and scaling policies.

## B

**Batch Inference**
Processing multiple inputs simultaneously for efficiency rather than processing them individually.
*Infrastructure Impact*: Higher throughput but increased latency; requires batching logic in serving infrastructure.

**Batch Size**
The number of training examples processed together in one forward/backward pass.
*Infrastructure Impact*: Larger batch sizes require more GPU memory but can improve training efficiency.

**BERT (Bidirectional Encoder Representations from Transformers)**
A popular transformer-based model architecture for natural language understanding.
*Infrastructure Impact*: Moderate resource requirements; good for CPU or smaller GPU deployments.

## C

**Checkpoint**
A saved snapshot of a model's state during training, allowing training to resume from that point.
*Infrastructure Impact*: Requires reliable storage (S3) and affects training job fault tolerance.

**CUDA**
NVIDIA's parallel computing platform and programming model for GPUs.
*Infrastructure Impact*: Required for GPU acceleration; affects container image selection and driver requirements.

**Container Registry**
A service for storing and distributing container images.
*Infrastructure Impact*: Critical for AI/ML deployments; consider bandwidth and caching for large model images.

## D

**Data Parallelism**
Distributing training data across multiple devices while keeping the model architecture the same on each device.
*Infrastructure Impact*: Requires high-bandwidth networking between nodes for gradient synchronization.

**Distributed Training**
Training a model across multiple compute resources (GPUs, nodes) simultaneously.
*Infrastructure Impact*: Requires specialized networking (EFA), orchestration, and fault tolerance mechanisms.

**Dynamic Batching**
Combining inference requests into batches on-the-fly to improve throughput.
*Infrastructure Impact*: Improves GPU utilization but requires sophisticated request queuing and batching logic.

## E

**Embedding**
A dense vector representation of data (text, images, etc.) that captures semantic meaning.
*Infrastructure Impact*: Embedding models are typically smaller and have high throughput requirements.

**Epoch**
One complete pass through the entire training dataset.
*Infrastructure Impact*: Training jobs may run for many epochs, requiring sustained compute resources.

**EFA (Elastic Fabric Adapter)**
AWS's high-performance networking interface for HPC and ML workloads.
*Infrastructure Impact*: Essential for large-scale distributed training; requires specific instance types.

## F

**Fine-tuning**
Adapting a pre-trained model to a specific task with additional training on domain-specific data.
*Infrastructure Impact*: Requires less compute than training from scratch but still needs GPU resources.

**Foundation Model**
Large-scale models trained on diverse data that can be adapted to many downstream tasks.
*Infrastructure Impact*: Very large models requiring significant GPU memory and specialized serving techniques.

**FP16/BF16**
Half-precision floating-point formats that reduce memory usage and increase training speed.
*Infrastructure Impact*: Reduces GPU memory requirements and can improve performance on modern GPUs.

## G

**GPU (Graphics Processing Unit)**
Specialized processors designed for parallel computation, essential for AI/ML workloads.
*Infrastructure Impact*: Primary compute resource for AI/ML; affects instance type selection and cost.

**Gradient**
The derivative of the loss function with respect to model parameters, used to update the model during training.
*Infrastructure Impact*: Gradients must be synchronized across devices in distributed training.

**GPT (Generative Pre-trained Transformer)**
A family of large language models based on the transformer architecture.
*Infrastructure Impact*: Large models requiring significant GPU memory and optimized serving infrastructure.

## H

**HPA (Horizontal Pod Autoscaler)**
Kubernetes feature that automatically scales the number of pods based on metrics.
*Infrastructure Impact*: Essential for cost-effective inference serving; requires proper metric configuration.

**Hyperparameter**
Configuration settings for training algorithms (learning rate, batch size, etc.).
*Infrastructure Impact*: Hyperparameter tuning requires running multiple training jobs, affecting resource planning.

**HuggingFace**
Popular platform and library for sharing and using pre-trained models, especially for NLP.
*Infrastructure Impact*: Provides easy model access but requires internet connectivity and model caching strategies.

## I

**Inference**
Using a trained model to make predictions on new data.
*Infrastructure Impact*: Different resource requirements than training; focus on latency and throughput optimization.

**Instance Storage**
High-speed, directly attached storage on EC2 instances.
*Infrastructure Impact*: Excellent for temporary data and caching but data is lost when instance stops.

## J

**JAX**
A NumPy-compatible library for machine learning research with automatic differentiation and JIT compilation.
*Infrastructure Impact*: Excellent performance through XLA compilation; good TPU support.

## K

**Kubernetes Operator**
Software that extends Kubernetes to manage complex applications automatically.
*Infrastructure Impact*: Simplifies deployment and management of distributed AI/ML workloads.

**KubeRay**
Kubernetes operator for deploying and managing Ray clusters.
*Infrastructure Impact*: Enables easy deployment of distributed Ray workloads on Kubernetes.

## L

**Latency**
The time between sending a request and receiving a response.
*Infrastructure Impact*: Critical metric for real-time inference; affects user experience and architecture decisions.

**LLM (Large Language Model)**
Neural networks with billions of parameters trained on large text datasets.
*Infrastructure Impact*: Require significant GPU memory and specialized serving techniques like tensor parallelism.

**Load Balancer**
Distributes incoming requests across multiple servers or pods.
*Infrastructure Impact*: Essential for high-availability inference serving; affects network architecture.

## M

**Model Parallelism**
Distributing different parts of a model across multiple devices.
*Infrastructure Impact*: Enables training/serving of very large models but increases communication overhead.

**Model Registry**
A centralized repository for storing, versioning, and managing machine learning models.
*Infrastructure Impact*: Critical for MLOps; affects deployment pipelines and model governance.

**Multi-GPU**
Using multiple GPUs simultaneously for training or inference.
*Infrastructure Impact*: Requires high-bandwidth interconnects and specialized software frameworks.

## N

**NFS (Network File System)**
A distributed file system protocol allowing access to files over a network.
*Infrastructure Impact*: Used by EFS; provides shared storage but with network latency considerations.

**Node Affinity**
Kubernetes feature to constrain pods to run on particular nodes.
*Infrastructure Impact*: Essential for ensuring AI workloads run on appropriate hardware (GPU nodes).

**NVIDIA Triton**
High-performance inference serving system supporting multiple ML frameworks.
*Infrastructure Impact*: Provides production-ready model serving with advanced features like dynamic batching.

## O

**ONNX (Open Neural Network Exchange)**
Open standard for representing machine learning models.
*Infrastructure Impact*: Enables framework interoperability and optimized inference across different platforms.

**Operator**
See Kubernetes Operator.

## P

**Parameter**
Learnable weights in a neural network model.
*Infrastructure Impact*: Number of parameters directly affects memory requirements and model size.

**Pipeline Parallelism**
Splitting a model into sequential stages that run on different devices.
*Infrastructure Impact*: Balances computation and communication but can have pipeline bubble inefficiencies.

**Pod**
The smallest deployable unit in Kubernetes, containing one or more containers.
*Infrastructure Impact*: Basic unit for resource allocation and scheduling in Kubernetes.

**Pre-training**
Initial training of a model on a large, general dataset before fine-tuning.
*Infrastructure Impact*: Requires massive compute resources and long training times.

**PyTorch**
Popular open-source machine learning framework.
*Infrastructure Impact*: Dynamic computation graphs; excellent for research but requires careful resource management.

## Q

**Quantization**
Reducing the precision of model weights to decrease memory usage and increase inference speed.
*Infrastructure Impact*: Reduces GPU memory requirements and can improve performance with minimal accuracy loss.

**Queue**
A data structure for managing requests in order.
*Infrastructure Impact*: Important for managing inference requests and implementing batching strategies.

## R

**Ray**
Distributed computing framework for scaling Python applications.
*Infrastructure Impact*: Provides unified platform for distributed training, tuning, and serving.

**Replica**
A copy of a pod or deployment in Kubernetes.
*Infrastructure Impact*: Used for scaling and high availability; affects resource allocation and costs.

**Resource Quota**
Kubernetes feature to limit resource consumption within a namespace.
*Infrastructure Impact*: Prevents resource contention and helps manage costs in multi-tenant environments.

## S

**Scaling**
Adjusting compute resources based on demand (horizontal: more instances, vertical: more powerful instances).
*Infrastructure Impact*: Critical for cost optimization and performance; requires proper monitoring and policies.

**Serverless**
Computing model where the cloud provider manages server provisioning and scaling.
*Infrastructure Impact*: Can reduce operational overhead but may have cold start latency for AI workloads.

**Storage Class**
Kubernetes abstraction for different types of storage with different performance characteristics.
*Infrastructure Impact*: Defines storage performance and cost characteristics for persistent volumes.

## T

**Tensor**
Multi-dimensional array used to represent data in machine learning.
*Infrastructure Impact*: Tensor operations are the primary compute workload for AI/ML applications.

**TensorFlow**
Popular open-source machine learning framework developed by Google.
*Infrastructure Impact*: Static computation graphs (TF 1.x) provide predictable memory usage; strong serving ecosystem.

**Throughput**
The number of requests or operations processed per unit time.
*Infrastructure Impact*: Key metric for batch processing and high-volume inference serving.

**Tokenization**
Converting text into numerical tokens that models can process.
*Infrastructure Impact*: Preprocessing step that affects input pipeline performance and latency.

**Training**
The process of teaching a machine learning model using data.
*Infrastructure Impact*: Compute-intensive process requiring sustained high-performance resources.

## V

**vLLM**
High-throughput and memory-efficient inference library for large language models.
*Infrastructure Impact*: Significantly improves LLM serving performance through techniques like PagedAttention.

**Volume**
Kubernetes abstraction for storage that can be mounted into containers.
*Infrastructure Impact*: Provides persistent storage for models, data, and checkpoints.

## W

**Workload**
A specific type of computational task or application.
*Infrastructure Impact*: Different AI/ML workloads have different resource requirements and scaling patterns.

**Worker Node**
A node in a Kubernetes cluster that runs application pods.
*Infrastructure Impact*: Where AI/ML workloads actually execute; must have appropriate hardware (GPUs, etc.).

## Infrastructure-Specific Terms

**Auto Scaling Group (ASG)**
AWS service that automatically adjusts the number of EC2 instances.
*Infrastructure Impact*: Provides the foundation for Kubernetes cluster auto-scaling.

**Elastic Block Store (EBS)**
AWS block storage service for EC2 instances.
*Infrastructure Impact*: Provides persistent storage for Kubernetes persistent volumes.

**Elastic File System (EFS)**
AWS managed NFS file system.
*Infrastructure Impact*: Provides shared storage accessible from multiple pods and nodes.

**FSx for Lustre**
AWS high-performance file system optimized for compute-intensive workloads.
*Infrastructure Impact*: Provides high-throughput storage essential for large-scale training workloads.

**Inferentia**
AWS custom silicon designed for machine learning inference.
*Infrastructure Impact*: Cost-effective inference acceleration requiring model compilation with AWS Neuron.

**Karpenter**
Open-source Kubernetes cluster autoscaler.
*Infrastructure Impact*: Provides more flexible and efficient node provisioning than traditional cluster autoscaler.

**Trainium**
AWS custom silicon designed for machine learning training.
*Infrastructure Impact*: Cost-effective training acceleration requiring model optimization with AWS Neuron.

## Usage Tips for Infrastructure Engineers

1. **Start with the Basics**: Focus on understanding models, training vs. inference, and hardware requirements first.

2. **Think in Terms of Resources**: Always consider CPU, memory, GPU, storage, and network requirements for each concept.

3. **Consider Scale**: Most AI/ML concepts have different implications at different scales.

4. **Focus on Operations**: Understand how each concept affects deployment, monitoring, and maintenance.

5. **Plan for Growth**: Consider how each component scales as your AI/ML workloads grow.

## Next Steps

- Use this glossary as a reference while reading the other sections
- Refer back to specific concept guides for detailed explanations
- Proceed to the ["Why" section](../02-why/README.md) to understand architectural decisions

This glossary will be updated as new concepts and technologies emerge in the AI/ML infrastructure space.
