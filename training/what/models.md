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

### 2. Task-Specific Models

Models designed and trained for specific tasks or domains.

- **Examples**: BERT for text classification, ResNet for image recognition
- **Characteristics**:
  - Optimized for particular use cases
  - Generally smaller than foundation models
  - Higher accuracy for their specific domain

### 3. Embedding Models

Models that convert text, images, or other data into numerical vector representations.

- **Examples**: OpenAI's text-embedding-ada-002, CLIP
- **Characteristics**:
  - Create dense vector representations
  - Enable semantic search and similarity comparisons
  - Often used as components in larger AI systems

## Model Architectures

### Transformer Architecture

The dominant architecture for modern language models.

- **Key Components**:
  - Attention mechanisms
  - Feed-forward neural networks
  - Layer normalization
  - Positional encoding

### Convolutional Neural Networks (CNNs)

Primarily used for computer vision tasks.

- **Key Components**:
  - Convolutional layers
  - Pooling layers
  - Fully connected layers

### Diffusion Models

Used for generative tasks, especially image generation.

- **Key Components**:
  - Forward diffusion process
  - Reverse diffusion process
  - U-Net architecture

## Model Sizes and Capabilities

| Model Size | Parameter Count | Typical Use Cases | Resource Requirements |
|------------|----------------|-------------------|----------------------|
| Small      | <1B            | Text classification, simple NLP tasks | 1-2 GPUs |
| Medium     | 1B-10B         | Code generation, translation, summarization | 4-8 GPUs |
| Large      | 10B-100B       | Complex reasoning, creative content generation | Multiple GPU nodes |
| Very Large | >100B          | Advanced reasoning, multimodal tasks | Distributed training across many nodes |

## Model Formats and Weights

### Common Model Formats

- **PyTorch (.pt, .pth)**: Native format for PyTorch models
- **ONNX (.onnx)**: Open Neural Network Exchange format for interoperability
- **TensorFlow (.pb)**: Protocol Buffer format for TensorFlow models
- **Safetensors (.safetensors)**: Safe format for storing tensors
- **GGUF (.gguf)**: Successor to GGML format, optimized for quantized models

### Model Weights vs. Architecture

- **Model Weights**: The learned parameters of a model (what changes during training)
- **Model Architecture**: The structure and design of the neural network

### Quantization Formats

Quantization reduces model size and increases inference speed by using lower precision for weights.

- **FP32**: Full precision (32-bit floating point)
- **FP16**: Half precision (16-bit floating point)
- **BF16**: Brain floating point format
- **INT8**: 8-bit integer quantization
- **INT4**: 4-bit integer quantization

## Considerations for EKS Deployment

When deploying models on Amazon EKS, consider:

1. **Resource Requirements**: GPU memory, CPU, RAM needed for your model size
2. **Scaling Strategy**: Horizontal vs. vertical scaling based on model architecture
3. **Storage Access**: How model weights will be loaded (from S3, FSx, EFS)
4. **Optimization Techniques**: Quantization, distillation, or pruning to reduce resource needs
5. **Serving Framework**: Which inference server best matches your model type

## Next Steps

- Learn about [Training vs. Inference](training-vs-inference.md) workflows
- Explore [Inference Libraries and Backends](inference-libraries.md) for model deployment
