# Understanding AI/ML Models

## What is a Model?

An AI/ML model is a mathematical representation trained on data to make predictions or decisions without being explicitly programmed for a specific task. In the context of AI on EKS, models are typically deployed as containerized workloads that require specific compute resources and optimizations.

## Types of Models

### 1. Foundation Models

Foundation models are large-scale models trained on vast amounts of data that can be adapted to a wide range of downstream tasks.

- **Examples**: GPT-4, Llama 2, Claude, Falcon, Mistral
- **Characteristics**: 
  - Billions to trillions of parameters
  - Trained on diverse datasets
  - Can be fine-tuned for specific applications
  - Require significant compute resources

**Why it matters for infrastructure**: Foundation models require specialized deployment strategies due to their size. They often don't fit on a single GPU and need techniques like model parallelism or specialized serving solutions like vLLM.

**Learn more**: 
- [Stanford HAI Foundation Models](https://hai.stanford.edu/research/foundation-models)
- [AWS Foundation Models](https://aws.amazon.com/bedrock/foundation-models/)

### 2. Task-Specific Models

Models designed and trained for specific tasks or domains.

- **Examples**: BERT for text classification, ResNet for image recognition
- **Characteristics**:
  - Optimized for particular use cases
  - Generally smaller than foundation models
  - Higher accuracy for their specific domain

**Why it matters for infrastructure**: These models typically have more predictable resource requirements and can often run on a single GPU or even CPU. They're good candidates for standard Kubernetes deployments with appropriate resource requests.

**Learn more**:
- [Hugging Face Models Hub](https://huggingface.co/models)
- [TensorFlow Model Garden](https://github.com/tensorflow/models)

### 3. Embedding Models

Models that convert text, images, or other data into numerical vector representations.

- **Examples**: OpenAI's text-embedding-ada-002, CLIP
- **Characteristics**:
  - Create dense vector representations
  - Enable semantic search and similarity comparisons
  - Often used as components in larger AI systems

**Why it matters for infrastructure**: Embedding models are typically smaller and have high throughput requirements. They're often deployed alongside vector databases and need to be optimized for low-latency inference.

**Learn more**:
- [OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings)
- [Vector Databases Explained](https://www.pinecone.io/learn/vector-database/)

## Model Architectures

### Transformer Architecture

The dominant architecture for modern language models.

- **Key Components**:
  - **Attention Mechanisms**: Allow the model to focus on different parts of the input when generating each part of the output. This is crucial for understanding context in language.
  - **Feed-forward Neural Networks**: Process the attention outputs to extract higher-level features.
  - **Layer Normalization**: Stabilizes the learning process by normalizing the inputs across features.
  - **Positional Encoding**: Adds information about the position of tokens in the sequence, since the attention mechanism itself doesn't consider order.

**Why it matters for infrastructure**: Transformer models are compute-intensive during the attention calculation, which scales quadratically with sequence length. This has direct implications for GPU memory requirements and throughput.

**Learn more**:
- [The Illustrated Transformer](https://jalammar.github.io/illustrated-transformer/)
- [NVIDIA Transformer Engine](https://developer.nvidia.com/transformer-engine)

### Convolutional Neural Networks (CNNs)

Primarily used for computer vision tasks.

- **Key Components**:
  - **Convolutional Layers**: Apply filters to detect features like edges, textures, and patterns.
  - **Pooling Layers**: Reduce spatial dimensions while preserving important features.
  - **Fully Connected Layers**: Combine features for final classification or regression.

**Why it matters for infrastructure**: CNNs are highly parallelizable and benefit significantly from GPU acceleration. They typically have predictable memory usage based on image size and batch size.

**Learn more**:
- [CS231n CNN Explainer](https://poloclub.github.io/cnn-explainer/)
- [PyTorch Vision Models](https://pytorch.org/vision/stable/models.html)

### Diffusion Models

Used for generative tasks, especially image generation.

- **Key Components**:
  - **Forward Diffusion Process**: Gradually adds noise to data.
  - **Reverse Diffusion Process**: Learns to denoise and recover the original data distribution.
  - **U-Net Architecture**: Processes images at multiple resolutions to capture both fine details and overall structure.

**Why it matters for infrastructure**: Diffusion models require significant compute for generation, with inference time proportional to the number of denoising steps. They benefit from GPU acceleration and optimized inference techniques.

**Learn more**:
- [Hugging Face Diffusion Models](https://huggingface.co/docs/diffusers/index)
- [Stability AI Models](https://stability.ai/models)

## Model Sizes and Capabilities

| Model Size | Parameter Count | Typical Use Cases | Resource Requirements |
|------------|----------------|-------------------|----------------------|
| Small      | <1B            | Text classification, simple NLP tasks | 1-2 GPUs |
| Medium     | 1B-10B         | Code generation, translation, summarization | 4-8 GPUs |
| Large      | 10B-100B       | Complex reasoning, creative content generation | Multiple GPU nodes |
| Very Large | >100B          | Advanced reasoning, multimodal tasks | Distributed training across many nodes |

**Why model size matters for infrastructure**: The number of parameters directly impacts memory requirements, which determines the type and number of GPUs needed. Larger models may require specialized techniques like tensor parallelism or pipeline parallelism to fit in memory.

**Learn more**:
- [NVIDIA Large Language Model Guide](https://developer.nvidia.com/blog/deploying-large-language-models-in-production/)
- [AWS Trainium/Inferentia Sizing Guide](https://aws.amazon.com/machine-learning/inferentia/)

## Model Formats and Weights

### Common Model Formats

- **PyTorch (.pt, .pth)**: Native format for PyTorch models
- **ONNX (.onnx)**: Open Neural Network Exchange format for interoperability
- **TensorFlow (.pb)**: Protocol Buffer format for TensorFlow models
- **Safetensors (.safetensors)**: Safe format for storing tensors
- **GGUF (.gguf)**: Successor to GGML format, optimized for quantized models

**Why formats matter for infrastructure**: Different formats support different optimizations and deployment targets. Converting between formats may be necessary for optimal performance on specific hardware.

**Learn more**:
- [ONNX Model Zoo](https://github.com/onnx/models)
- [Safetensors Documentation](https://huggingface.co/docs/safetensors/index)
- [GGUF Format](https://github.com/ggerganov/ggml/blob/master/docs/gguf.md)

### Model Weights vs. Architecture

- **Model Weights**: The learned parameters of a model (what changes during training)
- **Model Architecture**: The structure and design of the neural network

**Why this distinction matters**: When deploying models, you need both the architecture definition and the weights. The architecture is typically small (code), while weights can be very large (gigabytes). This affects how you package and distribute your models.

### Quantization Formats

Quantization reduces model size and increases inference speed by using lower precision for weights.

- **FP32**: Full precision (32-bit floating point)
- **FP16**: Half precision (16-bit floating point)
- **BF16**: Brain floating point format
- **INT8**: 8-bit integer quantization
- **INT4**: 4-bit integer quantization

**Why quantization matters for infrastructure**: Quantized models require less memory and compute, enabling faster inference and deployment on smaller hardware. However, there may be accuracy trade-offs that need to be evaluated.

**Learn more**:
- [NVIDIA TensorRT Quantization](https://developer.nvidia.com/blog/achieving-fp32-accuracy-for-int8-inference-using-quantization-aware-training-with-tensorrt/)
- [PyTorch Quantization](https://pytorch.org/docs/stable/quantization.html)
- [AWS Neuron Quantization](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/general/appnotes/quantization.html)

## Considerations for EKS Deployment

When deploying models on Amazon EKS, consider:

1. **Resource Requirements**: GPU memory, CPU, RAM needed for your model size
2. **Scaling Strategy**: Horizontal vs. vertical scaling based on model architecture
3. **Storage Access**: How model weights will be loaded (from S3, FSx, EFS)
4. **Optimization Techniques**: Quantization, distillation, or pruning to reduce resource needs
5. **Serving Framework**: Which inference server best matches your model type

**Why these considerations matter**: Proper resource allocation and optimization are critical for cost-effective and performant AI deployments. Mismatched resources can lead to out-of-memory errors, poor performance, or unnecessary costs.

**Learn more**:
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [NVIDIA GPU Operator for Kubernetes](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/overview.html)
- [KServe Documentation](https://kserve.github.io/website/latest/)

## Next Steps

- Learn about [Training vs. Inference](training-vs-inference.md) workflows
- Explore [Inference Libraries and Backends](inference-libraries.md) for model deployment
