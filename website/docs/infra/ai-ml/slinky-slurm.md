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

![alt text](img/Slurm-on-EKS.png)

The diagram above depicts the Slurm on EKS deployment outlined in this guide. An Amazon EKS cluster acts as an orchestration layer, with core Slurm Cluster components hosted on a managed node group of m5.xlarge instances, while a Karpenter NodePool manages the deployment of GPU accelerated compute nodes for the slurmd pods to run on. The Slinky Slurm operator and Slurm cluster are automatically deployed as ArgoCD applications. 

The login LoadBalancer type service is annotated to dynamically create an AWS Network Load Balancer using the [AWS Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller), allowing ML scientists to SSH into the login pod without interfacing with the Kubernetes API server via kubectl.

The login and slurmd pods also have an [Amazon FSx for Lustre](https://aws.amazon.com/fsx/lustre/) shared filesystem mounted. Having containerized slurmd pods allows many dependencies that would traditionally be installed manually using Conda or a Python virtual environment to be baked into the container image, but shared filesystems are still beneficial for storing training artifacts, data, logs, and checkpoints.

### Key Features and Benefits

- Run Slurm workloads side by side with containerized Kubernetes applications on the same infrastructure. Both Slurm and Kubernetes workloads can be scheduled on the same node pools, increasing utilization and avoiding resource fragmentation.
- Manage both Slurm jobs and Kubernetes pods seamlessly, leveraging familiar tooling from both ecosystems without sacrificing control or performance. 
- Dynamically add or removes compute nodes in response to workload demand, autoscaling allocated resources efficiently, handling spikes and lulls in demand to reduce infrastructure costs and idle resource waste. 
- High-availability through Kubernetes orchestration. If a controller or worker pod fails, Kubernetes automatically restarts it, reducing manual intervention.
- Slurm’s sophisticated scheduling features (fair-share allocation, dependency management, priority scheduling) are integrated into Kubernetes, maximizing compute utilization and aligning resources with workload requirements. 
- Slurm and its dependencies are deployed as containers, ensuring consistent deployments across environments. This reduces configuration drift and streamlines dev-to-prod transitions. 
- Users can build Slurm images tailored to specialized needs (e.g., custom dependencies, libraries), promoting consistency and repeatability in scientific or regulated environments. 
- Administrators can define custom Slurm clusters and node sets directly using Kubernetes Custom Resources, including partitioning compute nodes for different types of jobs (e.g., stable vs. opportunistic/backfill partitions)
- Slinky integrates with monitoring stacks for both Slurm and Kubernetes, providing robust metrics and visualization for administrators and users. 

<CollapsibleContent header={<h2><span>Deploying the Solution</span></h2>}>

In this example, you will provision a Slinky Slurm cluster on Amazon EKS. 

**0. Prerequisites:**

Ensure that you have installed the following tools on your machine.

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
4. [docker](https://docs.docker.com/engine/install/)

**1. Clone the repository:**

```bash
git clone https://github.com/awslabs/ai-on-eks.git
```

:::info
If you are using profile for authentication
set your `export AWS_PROFILE="<PROFILE_name>"` to the desired profile name
:::

**2. Review and customize configurations:**

- Check available addons in `infra/base/terraform/variables.tf`
- Modify addon settings in `infra/slinky-slurm/terraform/blueprint.tfvars` as needed
- Update the AWS region in `blueprint.tfvars`

**3. Review the slurmd container image build automation:**

By default, the `infra/slinky-slurm/install.sh` script will trigger setup steps to automatically build a new slurmd container image using the `infra/slinky-slurm/dlc-slurmd.Dockerfile`, which builds on top of an [AWS Deep Learning Container (DLC)](https://github.com/aws/deep-learning-containers) to include Python 3.12.8 + PyTorch 2.6.0 + CUDA 12.6 + NCCL 2.23.4 + EFA Installer 1.38.0 (bundled with OFI NCCL plugin) pre-installed in the container image. 

It will then create a new ECR repository and push this image to the repository. If not already present on your machine, a new SSH key `~/.ssh/id_ed25519_slurm` will be created for Slurm login pod access as well. 

The image repository URI, image tag, and public SSH key are then set in `infra/slinky-slurm/terraform/blueprint.tfvars` to be used in the deployment of the Slurm cluster ArgoCD application. 

To customize this behavior, you can add the following optional flags:
| Component | Description | Default Value|
|-----------|-------------|-------------|
|`--repo-name`| The name of the ECR repository |dlc-slurmd|
|`--tag`|The image tag |25.05.0-ubuntu24.04|
|`--region`| The AWS region of your ECR repository | inferred from the AWS CLI configuration or set to `us-west-2`|
|`--skip-build`| Set if using an existing image already in ECR | `false`|
|`--skip-repo`| Set if targeting an existing ECR repository for a new image build |`false`|
|`--skip-setup`| Set if you manually added `image_repository`, `image_tag`, and `ssh_key` values in `infra/slinky-slurm/terraform/blueprint.tfvars`|`false`| 
|`--help`| View flag options |`false`|

For example, if you've already built and pushed a custom slurmd container image to a custom ECR repository, add the following flags and values:
```
cd ai-on-eks/infra/slinky-slurm
./install.sh --repo-name my-custom-repo --tag my-custom-tag --skip-build
``` 
The script will then validate that the container image exists in your ECR repo before proceeding. 

If you wish to use a custom Dockerfile, simply overwrite the contents of the `infra/slinky-slurm/dlc-slurmd.Dockerfile` before executing `infra/slinky-slurm/install.sh`. 

**4. Trigger deployment:**

Navigate into the `slinky-slurm` directory and run `install.sh` script:
```bash
cd ai-on-eks/infra/slinky-slurm
./install.sh
```
</CollapsibleContent>

<CollapsibleContent header={<h3><span>Verify Deployment</span></h3>}>

**0. Check Kubernetes Resources for Slurm Deployment:**

Update your local kubeconfig to access your kubernetes cluster:
```
aws eks update-kubeconfig --name slurm-on-eks
```

Verify the deployment status of the Slinky Slurm Operator: 
```
kubectl get all -n slinky
```
```
NAME                                         READY   STATUS    RESTARTS   AGE
pod/slurm-operator-bb5c58dc6-5rsjg           1/1     Running   0          41m
pod/slurm-operator-webhook-87bc59884-vw8rx   1/1     Running   0          41m

NAME                             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/slurm-operator           ClusterIP   None             <none>        8080/TCP,8081/TCP   41m
service/slurm-operator-webhook   ClusterIP   172.20.229.194   <none>        443/TCP,8081/TCP    41m

NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/slurm-operator           1/1     1            1           41m
deployment.apps/slurm-operator-webhook   1/1     1            1           41m

NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/slurm-operator-bb5c58dc6           1         1         1       41m
replicaset.apps/slurm-operator-webhook-87bc59884   1         1         1       41m
```

Verify the deployment status the Slurm Cluster: 
```
kubectl get all -n slurm
```
```
# TODO 
```
**1. Access the Slurm login Pod:**

SSH into the login pod: 
```
SLURM_LOGIN_HOSTNAME="$(kubectl get services \
 -n slurm -l app.kubernetes.io/instance=slurm,app.kubernetes.io/name=login \
 -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}")"

ssh -i ~/.ssh/id_ed25519_slurm -p 22 root@$SLURM_LOGIN_HOSTNAME
```
Check the available nodes: 
```
sinfo 
```
Verify that the Amazon FSx for Lustre shared file system is mounted to the login pod: 
```
df -h
```
```
# TODO 
```
Exit back to your machine: 
```
exit
```
**2. Access a Slurm Compute Pod:**

Open an interactive terminal session with one of the slurm compute nodes: 
```
kubectl -n slurm exec -it pod/slurm-compute-node-0 -- bash --login
```
Verify that the Amazon FSx for Lustre shared file system is mounted to the login pod: 
```
df -h
```
```
# TODO 
```
Check the installed CUDA compiler version on compute node pods:
```
nvcc --version
```
```
# nvcc: NVIDIA (R) Cuda compiler driver
# Copyright (c) 2005-2024 NVIDIA Corporation
# Built on Tue_Oct_29_23:50:19_PDT_2024
# Cuda compilation tools, release 12.6, V12.6.85
# Build cuda_12.6.r12.6/compiler.35059454_0
```
Check the NCCL version on compute node pods:
```
ldconfig -v | grep "libnccl.so" | tail -n1 | sed -r 's/^.*\.so\.//'
```
```
# 2.23.4
```
Check EFA availability:
```
ls /sys/class/infiniband/
fi_info -p efa 
```
ls /opt/amazon/efa/lib
ls /opt/amazon/ofi-nccl/lib/x86_64-linux-gnu
```
# TODO 
```
Check that the EFA libraries are properly mounted:
```
```
```
# TODO 
```
Verify EFA device allocation:
```
ls -l /dev/infiniband/
```
```
# TODO 
```
Verify intra-node GPU topology:
```
nvidia-smi topo -m
```
```
# TODO
```
Exit back to your machine: 
```
exit
```
</CollapsibleContent>

<CollapsibleContent header={<h3><span>Run FSDP Example</span></h3>}>

**0. Stage Training Artifacts:**

SSH into the login pod: 
```
SLURM_LOGIN_HOSTNAME="$(kubectl get services \
 -n slurm -l app.kubernetes.io/instance=slurm,app.kubernetes.io/name=login \
 -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}")"

ssh -i ~/.ssh/id_ed25519_slurm -p 22 root@$SLURM_LOGIN_HOSTNAME
```
Install Git on the login pod:
```
apt update
apt install -y git 
git --version 
```
Change directories into the FSx mount:
```
cd /fsx
```
Clone the [awsome-distributed-training](https://github.com/aws-samples/awsome-distributed-training) repo:
```
git clone https://github.com/aws-samples/awsome-distributed-training/
```
Change into the FSDP for Slurm example directory: 
```
cd awsome-distributed-training/3.test_cases/pytorch/FSDP/slurm
```
Make a new directory for your checkpoints
```
mkdir -p checkpoints
```
Copy the `llama2_7b-training.sbatch` batch training script: 
```
cp /fsx/data/llama2_7b-training.sbatch ./llama2_7b-training.sbatch
```
**1. Configure Hugging Face Access Token:**

Create a new [Hugging Face](https://huggingface.co/) read access token to stream the [allenai/c4](https://huggingface.co/datasets/allenai/c4) dataset without throttling. 

Inject the new Hugging Face token into the training script: 
```
NEW_TOKEN="<you-token-here>"
sed -i "s/export HF_TOKEN=.*$/export HF_TOKEN=$NEW_TOKEN/" llama2_7b-training.sbatch
```
**2. Start the training job:** 

Submit the batch training script to the Slurm Controller using the [sbatch](https://slurm.schedmd.com/sbatch.html) command: 
```
sbatch llama2_7b-training.sbatch
```
**3. Monitor trianing progess:**

Watch the output logs from the login pod:
```
export JOB_ID=$(squeue -h -u root -o "%i" | head -1)

tail -f logs/llama2_7b-FSDP_${JOB_ID}.out
```
Watch the error logs from `slurm-compute-node-0` (in a new terminal window):
```
kubectl -n slurm exec -it pod/slurm-compute-hp-node-0 -- bash --login

cd /fsx/awsome-distributed-training/3.test_cases/pytorch/FSDP/slurm
export JOB_ID=$(squeue -h -u root -o "%i" | head -1)

watch "grep 'Batch.*Loss' logs/llama2_7b-FSDP_${JOB_ID}.err"

# or

tail -f logs/llama2_7b-FSDP_${JOB_ID}.err | grep --line-buffered 'Batch.*Loss'
```
Watch squeue from `slurm-compute-node-1` (in a new terminal window):
```
kubectl -n slurm exec -it pod/slurm-compute-hp-node-1 -- bash --login

# 1 second updates
watch -n 1 squeue
```
Watch checkpoints from `slurm-compute-node-2` (in a new terminal window):
```
kubectl -n slurm exec -it pod/slurm-compute-hp-node-2 -- bash --login

cd /fsx/awsome-distributed-training/3.test_cases/pytorch/FSDP/slurm

# highlight changes, show timestamps, 5 second updates
watch -n 5 -d "ls -lh checkpoints"
```
Exit back to your machine: 
```
exit
```
</CollapsibleContent>

<CollapsibleContent header={<h3><span>Clean Up</span></h3>}>

:::caution
To avoid unwanted charges to your AWS account, delete all the AWS resources created during this deployment.
:::

This script will cleanup the environment using `-target` option to ensure all the resources are deleted in correct order.

```bash
cd ai-on-eks/infra/slinky-slurm
./cleanup.sh
```

</CollapsibleContent>