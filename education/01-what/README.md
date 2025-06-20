# Foundational Concepts: The "What" of AI on EKS

This section covers the fundamental concepts and components of AI/ML workloads on Amazon EKS. It's designed for cloud and DevOps professionals who are familiar with Kubernetes but may be new to AI/ML workloads.

## Contents

1. [AI/ML Models](01-models.md)
   - Types of models and their infrastructure implications
   - Model architectures and their computational characteristics
   - Model sizes and resource requirements
   - Model formats and optimization techniques

2. [Training vs. Inference](02-training-vs-inference.md)
   - Understanding the different phases of ML workflows
   - Resource requirements for each phase
   - Deployment patterns and scaling strategies
   - EKS-specific considerations

3. [AI/ML Frameworks and Ecosystem](03-frameworks-ecosystem.md)
   - Major frameworks: PyTorch, TensorFlow, JAX, and specialized libraries
   - Framework characteristics and infrastructure implications
   - Container strategies and Kubernetes integration
   - Best practices for framework deployment

4. [Inference Libraries and Backends](04-inference-libraries.md)
   - vLLM, TensorRT-LLM, and other optimization libraries
   - Performance characteristics and use cases
   - Selection criteria for different workloads
   - Integration with Kubernetes

5. [Inference Servers](05-inference-servers.md)
   - NVIDIA Triton Server, vLLM serving, and other options
   - Deployment patterns on EKS
   - Scaling and performance optimization
   - Request handling and monitoring

6. [Distributed Computing Frameworks](06-distributed-computing.md)
   - Ray and KubeRay for distributed AI workloads
   - Distributed training and inference patterns
   - Scaling strategies on EKS
   - Resource management and fault tolerance

7. [Storage Solutions for AI/ML](07-storage-solutions.md)
   - Amazon FSx, S3, EFS, and instance storage
   - Performance characteristics for AI workloads
   - Storage patterns for different use cases
   - EKS integration and best practices

8. [Hardware Options](08-hardware-options.md)
   - NVIDIA GPUs, AWS Trainium, AWS Inferentia
   - Selection criteria for different workloads
   - Resource allocation and optimization
   - EKS node group configurations

9. [AI/ML Workload Patterns](09-workload-patterns.md)
   - Common deployment patterns for AI/ML workloads
   - Batch processing, real-time serving, and interactive development
   - Infrastructure requirements for different patterns
   - Best practices for workload design

10. [Summary and Integration](10-summary.md)
    - Comprehensive recap of all foundational concepts
    - Infrastructure decision matrix and common patterns
    - Integration with repository examples
    - Key principles and common pitfalls to avoid

11. [Glossary](11-glossary.md)
    - Comprehensive glossary of AI/ML terms for infrastructure engineers
    - Definitions focused on infrastructure implications
    - Quick reference for technical concepts

## AI on EKS Repository Examples

Throughout this section, we reference practical examples from this repository:

- **Infrastructure Examples**: See [/infra/base/terraform](../../infra/base/terraform) for foundational infrastructure components
- **Training Blueprints**: Explore [/blueprints/training](../../blueprints/training) for distributed training patterns
- **Inference Blueprints**: Check [/blueprints/inference](../../blueprints/inference) for various inference deployment patterns
- **Specialized Solutions**: Review specific solutions like [JARK Stack](../../infra/jark-stack), [NVIDIA Triton](../../infra/nvidia-triton-server), and [Trainium/Inferentia](../../infra/trainium-inferentia)

## How to Use This Section

This section provides foundational knowledge about AI/ML components and their deployment on EKS. It focuses on explaining what these components are and how they fit into the overall architecture.

For each topic, we provide:
- Clear explanations of concepts with minimal AI/ML jargon
- Infrastructure implications that matter to DevOps and cloud engineers
- Official documentation links for further reading
- Practical considerations for EKS deployments
- References to working examples in this repository

After understanding these foundational concepts, proceed to the ["Why" section](../02-why/README.md) to learn about architectural decisions and trade-offs in AI/ML deployments on EKS.
