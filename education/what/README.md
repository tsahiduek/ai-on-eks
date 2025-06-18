# Foundational Concepts: The "What" of AI on EKS

This section covers the fundamental concepts and components of AI/ML workloads on Amazon EKS. It's designed for cloud and DevOps professionals who are familiar with Kubernetes but may be new to AI/ML workloads.

## Contents

1. [AI/ML Models](models.md)
   - Types of models and their infrastructure implications
   - Model architectures and their computational characteristics
   - Model sizes and resource requirements
   - Model formats and optimization techniques

2. [Training vs. Inference](training-vs-inference.md)
   - Understanding the different phases of ML workflows
   - Resource requirements for each phase
   - Deployment patterns and scaling strategies
   - EKS-specific considerations

3. [Inference Libraries and Backends](inference-libraries.md)
   - vLLM, TensorRT-LLM, and other optimization libraries
   - Performance characteristics and use cases
   - Selection criteria for different workloads
   - Integration with Kubernetes

4. [Inference Servers](inference-servers.md)
   - NVIDIA Triton Server, vLLM serving, and other options
   - Deployment patterns on EKS
   - Scaling and performance optimization
   - Request handling and monitoring

5. [Distributed Computing Frameworks](distributed-computing.md)
   - Ray and KubeRay for distributed AI workloads
   - Distributed training and inference patterns
   - Scaling strategies on EKS
   - Resource management and fault tolerance

6. [Storage Solutions for AI/ML](storage-solutions.md)
   - Amazon FSx, S3, EFS, and instance storage
   - Performance characteristics for AI workloads
   - Storage patterns for different use cases
   - EKS integration and best practices

7. [Hardware Options](hardware-options.md)
   - NVIDIA GPUs, AWS Trainium, AWS Inferentia
   - Selection criteria for different workloads
   - Resource allocation and optimization
   - EKS node group configurations

## How to Use This Section

This section provides foundational knowledge about AI/ML components and their deployment on EKS. It focuses on explaining what these components are and how they fit into the overall architecture.

For each topic, we provide:
- Clear explanations of concepts with minimal AI/ML jargon
- Infrastructure implications that matter to DevOps and cloud engineers
- Official documentation links for further reading
- Practical considerations for EKS deployments

After understanding these foundational concepts, proceed to the ["Why" section](../why/README.md) to learn about architectural decisions and trade-offs in AI/ML deployments on EKS.
