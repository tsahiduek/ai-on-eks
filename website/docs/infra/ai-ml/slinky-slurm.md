---
sidebar_label: Slurm on EKS
---

import CollapsibleContent from '../../../src/components/CollapsibleContent';

# Slurm on EKS

:::warning
Deployment of ML models on EKS requires access to GPUs or Neuron instances. If your deployment isn't working, it’s often due to missing access to these resources. Also, some deployment patterns rely on Karpenter autoscaling and static node groups; if nodes aren't initializing, check the logs for Karpenter or Node groups to resolve the issue.
:::

### What is Slurm?

[Slurm](https://slurm.schedmd.com/overview.html) is an open-source, highly scalable workload manager and job scheduler designed for managing compute resources on compute clusters of all sizes. It provides three core functions: allocating access to compute resources, providing a framework for launching and monitoring parallel computing jobs, and managing queues of pending work to resolve resource contention. 

Slurm is widely used in AI training to manage and schedule large-scale, GPU-accelerated workloads across high-performance computing clusters. It allows researchers and engineers to efficiently allocate computing resources, including CPUs, GPUs and memory, enabling distributed training of deep learning models and large language models by spanning jobs across many nodes with fine-grained control over resource types and job priorities. Slurm’s reliability, advanced scheduling features, and integration with both on-premise and cloud environments make it a preferred choice for handling the scale, throughput, and reproducibility that modern AI research and industry demand. 

### What is the Slinky Project? 

The [Slinky Project](https://github.com/SlinkyProject) is an open-source suite of integration tools designed by [SchedMD](https://www.schedmd.com/) (the lead developers of Slurm) to bring Slurm capabilities into Kubernetes, combining the best of both worlds for efficient resource management and scheduling. The Slinky Project includes a [Kubernetes operator for Slurm clusters](https://github.com/SlinkyProject/slurm-operator?tab=readme-ov-file#kubernetes-operator-for-slurm-clusters), which implements [custom-controllers](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-controllers) and [custom resource definitions (CRDs)](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#customresourcedefinitions) to manage the lifecycle of Slurm Cluster and NodeSet resources deployed within a Kubernetes environment. 

This Slurm cluster includes the following components:
| Component | Description |
|-----------|-------------|
| Controller (slurmctld) | The central management daemon that monitors resources, accepts jobs, and assigns work to compute nodes. |
| Accounting (slurmdbd) | Handles job accounting and user/project management through a MariaDB database backend. |
| Compute (slurmd) | The worker nodes that execute jobs, organized into NodeSets which can be grouped into different partitions. |
| Login | Provides SSH access points for users to interact with the Slurm cluster and submit jobs. |
| REST API (slurmrestd) | Offers HTTP-based API access to Slurm functionality for programmatic interaction with the cluster. |
| Authentication (sackd) | Manages credential authentication for secure access to Slurm services. |
| MariaDB | The database backend used by the accounting service to store job, user, and project information. |
| Slurm Exporter | Collects and exports Slurm metrics for monitoring purposes. |

When paired with Amazon EKS, the Slinky Project unlocks the ability for enterprises who have standardized infrastructure management on Kubernetes to deliver a Slurm-based experience to their ML scientists. It also enables training, experimentation, and inference to happen on the same cluster of accelerated nodes. 

### Slurm on EKS Architecture 

### Key Features and Benefits

<CollapsibleContent header={<h2><span>Deploying the Solution</span></h2>}>

</CollapsibleContent>

<CollapsibleContent header={<h3><span>Verify Deployment</span></h3>}>

</CollapsibleContent>

<CollapsibleContent header={<h3><span>Clean Up</span></h3>}>

</CollapsibleContent>