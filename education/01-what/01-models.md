# Understanding AI/ML Models

## What is a Model?

An AI/ML model is a mathematical representation trained on data to make predictions or decisions without being explicitly programmed for a specific task. In the context of AI on EKS, models are typically deployed as containerized workloads that require specific compute resources and optimizations.

From a files perspective, an AI/ML model consists of several key components stored as separate files:

- **Model Weights** (e.g., `.safetensors`, `.bin`, `.pt` files): These contain the learned parameters - the actual numerical values that the model acquired during training. These files are typically the largest, ranging from megabytes to hundreds of gigabytes.
- **Configuration File** (e.g., `config.json`): Contains metadata about the model architecture, hyperparameters, and settings that inference backends need to properly load and run the model. This tells the software how the model is structured and how to interpret the weights.
- **Tokenizer Files** (e.g., `tokenizer.json`, `vocab.txt`): For language models, these handle the conversion between human-readable text and numerical tokens that the model can process. The tokenizer encodes input text into numbers and decodes the model's numerical output back into readable text.

Together, these files form a complete model package that can be loaded by inference frameworks to serve predictions.

## Types of Models

### 1. Foundation Models

Foundation models can be categorized by size, each with different infrastructure implications:

**Large Foundation Models (7B+ parameters):**
Foundation models are large-scale models trained on vast amounts of data that can be adapted to a wide range of downstream tasks.

- **Examples**: GPT-4, Llama 2 70B, Claude, Falcon 40B, Mixtral 8x7B
- **Characteristics**: 
  - 7 billion to trillions of parameters
  - Trained on diverse datasets
  - Can be fine-tuned for specific applications
  - Require significant compute resources and specialized deployment techniques

**Small Language Models (1B-7B parameters):**
Smaller, more efficient models that still provide strong performance for many tasks.

- **Examples**: Llama 2 7B, Mistral 7B, Phi-3 Mini (3.8B), Gemma 2B
- **Characteristics**:
  - 1-7 billion parameters
  - Faster inference and lower resource requirements
  - Can often run on single GPUs
  - Good balance of performance and efficiency
  - Suitable for edge deployment and cost-conscious applications

**Why it matters**: Large foundation models require specialized deployment strategies due to their size and complexity. They often don't fit on a single GPU and need techniques like model parallelism or specialized serving solutions like vLLM. From a business perspective, they offer the most capabilities but come with higher operational costs and complexity. Small language models provide a good balance, offering strong performance while being more cost-effective and easier to deploy, making them suitable for many production use cases where the absolute best performance isn't required.

**Learn more**: 
- [Foundation Models Research - Stanford HAI](https://hai.stanford.edu/news/how-foundation-models-will-change-ai)
- [AWS Foundation Models](https://aws.amazon.com/bedrock/foundation-models/)
- [Hugging Face Foundation Models](https://huggingface.co/models?pipeline_tag=text-generation&sort=trending)

### 2. Task-Specific Models

Models designed and trained for specific tasks or domains.

- **Examples**: BERT for text classification, ResNet for image recognition
- **Characteristics**:
  - Optimized for particular use cases
  - Generally smaller than foundation models
  - Higher accuracy for their specific domain

**Why it matters**: These models typically have more predictable resource requirements and can often run on a single GPU or even CPU, making them ideal for standard Kubernetes deployments. From a business perspective, they offer faster time-to-market, lower operational costs, and higher accuracy for their specific domain compared to general-purpose models. They're often the right choice when you have well-defined use cases and don't need the broad capabilities of foundation models.

**Learn more**:
- [Hugging Face Models Hub](https://huggingface.co/models)
- [TensorFlow Model Garden](https://github.com/tensorflow/models)
- [PyTorch Hub Models](https://pytorch.org/hub/)

### 3. Embedding Models

Models that convert text, images, or other data into numerical vector representations.

- **Examples**: OpenAI's text-embedding-ada-002, CLIP
- **Characteristics**:
  - Create dense vector representations
  - Enable semantic search and similarity comparisons
  - Often used as components in larger AI systems

**Why it matters**: Embedding models are typically smaller and have high throughput requirements, making them cost-effective to deploy. They're often deployed alongside vector databases in retrieval-augmented generation (RAG) systems and need to be optimized for low-latency inference. From a business perspective, they enable semantic search, recommendation systems, and similarity matching capabilities that are essential for modern AI applications.

**Learn more**:
- [OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings)
- [Vector Databases Explained](https://www.pinecone.io/learn/vector-database/)
- [Sentence Transformers](https://www.sbert.net/)

## Model Architectures

### Transformer Architecture

The dominant architecture for modern language models.

- **Key Components**:
  - **Attention Mechanisms**: Allow the model to focus on different parts of the input when generating each part of the output. This is crucial for understanding context in language.
  - **Feed-forward Neural Networks**: These are simple neural networks that take the output from the attention mechanism and transform it through multiple layers to extract more complex patterns and relationships. Think of them as processing units that refine and enhance the information gathered by the attention mechanism, helping the model understand deeper meanings and connections in the data.
  - **Layer Normalization**: Stabilizes both training and inference by normalizing the inputs across features. During training, it helps the model learn more effectively by preventing internal values from becoming too large or small. During inference, it ensures consistent processing of inputs, maintaining the same numerical stability that the model learned during training.
  - **Positional Encoding**: Adds information about the position of tokens in the sequence, since the attention mechanism itself doesn't consider order.

**Why it matters**: Transformer models are compute-intensive during the attention calculation, which scales quadratically with sequence length. This has direct implications for GPU memory requirements and throughput. From a business perspective, longer input sequences (like long documents or conversations) require exponentially more resources, affecting both cost and performance. Understanding this helps in choosing the right model size and infrastructure for your specific use cases.

**Learn more**:
- [The Illustrated Transformer](https://jalammar.github.io/illustrated-transformer/)
- [NVIDIA Transformer Engine](https://developer.nvidia.com/transformer-engine)
- [Attention Is All You Need - Original Paper](https://arxiv.org/abs/1706.03762)

### Convolutional Neural Networks (CNNs)

Primarily used for computer vision tasks.

- **Key Components**:
  - **Convolutional Layers**: Apply filters to detect features like edges, textures, and patterns.
  - **Pooling Layers**: These layers downsample the image by taking the maximum or average value from small regions (like 2x2 pixel squares), effectively reducing the image size while keeping the most important information. For example, a 100x100 image might become 50x50 after pooling, making it faster to process while retaining the key features needed for recognition.
  - **Fully Connected Layers**: These final layers take all the features detected by previous layers and combine them to make the final prediction. The same CNN architecture can be used for different tasks by changing just this final layer - for classification (predicting categories like "cat" or "dog"), the output might be probabilities for each class, while for regression (predicting continuous values like "age of person in image"), the output would be a numerical value.

**Why it matters**: CNNs are highly parallelizable and benefit significantly from GPU acceleration, making them cost-effective for image processing tasks. They typically have predictable memory usage based on image size and batch size, which makes resource planning straightforward. From a business perspective, CNNs are mature, well-understood technology with many pre-trained models available, enabling faster development and deployment of computer vision applications.

**Learn more**:
- [CS231n CNN Explainer](https://poloclub.github.io/cnn-explainer/)
- [PyTorch Vision Models](https://pytorch.org/vision/stable/models.html)
- [TensorFlow Computer Vision Guide](https://www.tensorflow.org/tutorials/images/cnn)

### Diffusion Models

Used for generative tasks, especially image generation.

- **Key Components**:
  - **Forward Diffusion Process**: Gradually adds noise to data.
  - **Reverse Diffusion Process**: The model learns to remove noise step by step, like cleaning up a very blurry, noisy image to reveal a clear picture underneath. Starting from pure noise, the model gradually removes the noise in many small steps until it creates a high-quality image. It's like having an artist who can take a completely scrambled image and slowly, carefully restore it to look like a real photograph.
  - **U-Net Architecture**: Processes images at multiple resolutions to capture both fine details and overall structure.

**Why it matters**: Diffusion models require significant compute for generation, with inference time proportional to the number of denoising steps (typically 20-50 steps per image). They benefit from GPU acceleration and optimized inference techniques. From a business perspective, these models can generate high-quality, creative content but require more resources and time compared to other model types, making them suitable for applications where quality is more important than speed.

**Learn more**:
- [Hugging Face Diffusion Models](https://huggingface.co/docs/diffusers/index)
- [Stability AI Models](https://stability.ai/models)
- [Denoising Diffusion Probabilistic Models Paper](https://arxiv.org/abs/2006.11239)

## Model Sizes and Capabilities

| Model Size | Parameter Count | Typical Use Cases | Resource Requirements |
|------------|----------------|-------------------|----------------------|
| Small      | <1B            | Text classification, simple NLP tasks | 1-2 GPUs |
| Medium     | 1B-10B         | Code generation, translation, summarization | 4-8 GPUs |
| Large      | 10B-100B       | Complex reasoning, creative content generation | Multiple GPU nodes |
| Very Large | >100B          | Advanced reasoning, multimodal tasks | Distributed training across many nodes |

**Why model size matters**: The number of parameters directly impacts memory requirements, which determines the type and number of GPUs needed. Larger models may require specialized techniques like tensor parallelism or pipeline parallelism to fit in memory. From a business perspective, larger models generally provide better performance but come with exponentially higher costs for infrastructure, training, and inference. The key is finding the right balance between model capability and operational costs for your specific use case.

**Learn more**:
- [NVIDIA Large Language Model Guide](https://developer.nvidia.com/blog/deploying-large-language-models-in-production/)
- [AWS Trainium/Inferentia Sizing Guide](https://aws.amazon.com/machine-learning/inferentia/)
- [Model Size vs Performance Analysis](https://huggingface.co/blog/large-language-models)

## Model Formats and Weights

### Common Model Formats

- **PyTorch (.pt, .pth)**: Native format for PyTorch models
- **PyTorch Binary (.bin)**: Binary format often used for storing PyTorch model weights, commonly seen in Hugging Face model repositories
- **ONNX (.onnx)**: Open Neural Network Exchange format that allows models trained in one framework (like PyTorch) to be used in another framework (like TensorFlow) or optimized runtime. It's like a universal translator for AI models, enabling you to train in your preferred framework but deploy anywhere.
- **TensorFlow (.pb)**: Protocol Buffer format that stores both the model architecture and weights in a single, optimized file. It's TensorFlow's production-ready format that's optimized for inference speed and can be deployed without needing the original training code. It's particularly useful when you want a self-contained model file that includes everything needed for inference.
- **Safetensors (.safetensors)**: A secure format that prevents malicious code execution when loading model weights. Unlike pickle-based formats (.bin, .pt), safetensors files contain only the numerical data (weights) and cannot execute arbitrary code, making them safer to download and use from untrusted sources. They also load faster and use less memory than traditional formats.
- **GGUF (.gguf)**: Successor to GGML format, optimized for quantized models

**Why formats matter**: Different formats support different optimizations and deployment targets. Converting between formats may be necessary for optimal performance on specific hardware. From a security and operational perspective, choosing the right format affects loading speed, memory usage, and safety. Safetensors provides security benefits, while ONNX enables cross-platform deployment, and native formats (like .pb for TensorFlow) often provide the best performance for their respective frameworks.

**Learn more**:
- [ONNX Model Zoo](https://github.com/onnx/models)
- [Safetensors Documentation](https://huggingface.co/docs/safetensors/index)
- [Model Format Comparison Guide](https://huggingface.co/docs/transformers/serialization)

### Model Weights vs. Architecture

- **Model Weights**: The learned parameters of a model (what changes during training)
- **Model Architecture**: The structure and design of the neural network. As a user deploying pre-trained models, you typically receive the architecture as part of the model package (defined in configuration files). However, you can influence architecture through choices like selecting different model variants (e.g., Llama 2 7B vs 13B vs 70B), fine-tuning approaches, or when building custom models from scratch. For most deployment scenarios, you're working with established architectures rather than designing new ones.

**Why this distinction matters**: When deploying models, you need both the architecture definition and the weights. The architecture is typically small (code), while weights can be very large (gigabytes). This affects how you package and distribute your models.

### Quantization Formats

Quantization reduces model size and increases inference speed by using lower precision for weights.

- **FP32**: Full precision (32-bit floating point)
- **FP16**: Half precision (16-bit floating point)
- **BF16**: Brain floating point format
- **INT8**: 8-bit integer quantization
- **INT4**: 4-bit integer quantization

**Why quantization matters**: Quantized models require less memory and compute, enabling faster inference and deployment on smaller hardware. However, there may be accuracy trade-offs that need to be evaluated. From a business perspective, quantization can significantly reduce operational costs by allowing you to use smaller, cheaper hardware while maintaining acceptable performance. It's particularly valuable for edge deployment and cost-sensitive applications.

**Learn more**:
- [NVIDIA TensorRT Quantization](https://developer.nvidia.com/blog/achieving-fp32-accuracy-for-int8-inference-using-quantization-aware-training-with-tensorrt/)
- [PyTorch Quantization](https://pytorch.org/docs/stable/quantization.html)
- [Quantization Techniques Overview](https://huggingface.co/docs/transformers/quantization)

## Considerations for Deploying AI Workloads

When deploying models on Amazon EKS, consider:

1. **Resource Requirements**: GPU memory, CPU, RAM needed for your model size
2. **Scaling Strategy**: Horizontal vs. vertical scaling based on model architecture
3. **Storage Access**: How model weights will be loaded (from S3, FSx, EFS)
4. **Optimization Techniques**: Quantization, distillation, or pruning to reduce resource needs
5. **Serving Framework**: Which inference server best matches your model type

**Why these considerations matter**: Proper resource allocation and optimization are critical for cost-effective and performant AI deployments. Mismatched resources can lead to out-of-memory errors, poor performance, or unnecessary costs. From a business perspective, getting these considerations right from the start prevents costly redesigns, ensures reliable service delivery, and enables efficient scaling as your AI applications grow.

**Learn more**:
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [NVIDIA GPU Operator for Kubernetes](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/overview.html)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

## Next Steps

- Learn about [Training vs. Inference](02-training-vs-inference.md) workflows
- Explore [AI/ML Frameworks and Ecosystem](03-frameworks-ecosystem.md) to understand the foundational software stack

## Repository Examples

This repository contains practical examples of deploying various model types:

- **Large Language Models**: See [vLLM inference examples](../../blueprints/inference/vllm) for deploying LLMs like Llama 2, Mistral, and others
- **Foundation Model Serving**: Check [NVIDIA Triton examples](../../infra/nvidia-triton-server) for multi-framework model serving
- **Specialized Hardware**: Explore [Trainium/Inferentia examples](../../infra/trainium-inferentia) for AWS custom silicon deployments
- **Distributed Training**: Review [training blueprints](../../blueprints/training) for large model training patterns
