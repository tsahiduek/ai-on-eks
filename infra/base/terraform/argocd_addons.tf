resource "kubectl_manifest" "ai_ml_observability_yaml" {
  count     = var.enable_ai_ml_observability_stack ? 1 : 0
  yaml_body = file("${path.module}/argocd-addons/ai-ml-observability.yaml")

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubectl_manifest" "aibrix_dependency_yaml" {
  count     = var.enable_aibrix_stack ? 1 : 0
  yaml_body = templatefile("${path.module}/argocd-addons/aibrix-dependency.yaml", { aibrix_version = var.aibrix_stack_version })

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubectl_manifest" "aibrix_core_yaml" {
  count     = var.enable_aibrix_stack ? 1 : 0
  yaml_body = templatefile("${path.module}/argocd-addons/aibrix-core.yaml", { aibrix_version = var.aibrix_stack_version })

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubectl_manifest" "nvidia_nim_yaml" {
  count     = var.enable_nvidia_nim_stack ? 1 : 0
  yaml_body = file("${path.module}/argocd-addons/nvidia-nim-operator.yaml")

  depends_on = [
    module.eks_blueprints_addons
  ]
}

# NVIDIA K8s DRA Driver
resource "kubectl_manifest" "nvidia_dra_driver" {
  count     = var.enable_nvidia_dra_driver && var.enable_nvidia_gpu_operator ? 1 : 0
  yaml_body = file("${path.module}/argocd-addons/nvidia-dra-driver.yaml")

  depends_on = [
    module.eks_blueprints_addons
  ]
}

# GPU Operator
resource "kubectl_manifest" "nvidia_gpu_operator" {
  count = var.enable_nvidia_gpu_operator ? 1 : 0
  yaml_body = templatefile("${path.module}/argocd-addons/nvidia-gpu-operator.yaml", {
    service_monitor_enabled = var.enable_ai_ml_observability_stack
  })

  depends_on = [
    module.eks_blueprints_addons
  ]
}

# NVIDIA Device Plugin (standalone - GPU scheduling only)
resource "kubectl_manifest" "nvidia_device_plugin" {
  count     = !var.enable_nvidia_gpu_operator && var.enable_nvidia_device_plugin ? 1 : 0
  yaml_body = templatefile("${path.module}/argocd-addons/nvidia-device-plugin.yaml", {})

  depends_on = [
    module.eks_blueprints_addons
  ]
}

# DCGM Exporter (standalone - GPU monitoring only)
resource "kubectl_manifest" "nvidia_dcgm_exporter" {
  count = !var.enable_nvidia_gpu_operator && var.enable_nvidia_dcgm_exporter ? 1 : 0
  yaml_body = templatefile("${path.module}/argocd-addons/nvidia-dcgm-exporter.yaml", {
    service_monitor_enabled = var.enable_ai_ml_observability_stack
  })

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubectl_manifest" "cert_manager_yaml" {
  count     = var.enable_cert_manager || var.enable_slurm_operator || var.enable_slurm_cluster ? 1 : 0
  yaml_body = file("${path.module}/argocd-addons/slinky-slurm/cert-manager.yaml")

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "null_resource" "wait_for_cert_manager" {
  count = var.enable_slurm_operator || var.enable_slurm_cluster ? 1 : 0
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = pathexpand("~/.kube/config")
    }
    command = <<-EOT
      set -e
      aws eks --region ${var.region} update-kubeconfig --name ${var.name}
      bash ${path.module}/argocd-addons/slinky-slurm/wait-for-cert-manager.sh
    EOT
  }
  depends_on = [kubectl_manifest.cert_manager_yaml]
}

resource "kubectl_manifest" "slurm_operator_yaml" {
  count     = var.enable_slurm_operator || var.enable_slurm_cluster ? 1 : 0
  yaml_body = file("${path.module}/argocd-addons/slinky-slurm/slurm-operator.yaml")

  depends_on = [
    module.eks_blueprints_addons,
    kubectl_manifest.cert_manager_yaml,
    null_resource.wait_for_cert_manager
  ]
}

resource "kubectl_manifest" "priority_class" {
  count     = var.enable_slurm_cluster ? 1 : 0
  yaml_body = file("${path.module}/argocd-addons/slinky-slurm/slurm-node-priority-class.yaml")

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubectl_manifest" "slurm_cluster_yaml" {
  count = var.enable_slurm_cluster ? 1 : 0
  yaml_body = templatefile("${path.module}/argocd-addons/slinky-slurm/slurm-cluster.yaml", {
    slurm_values = indent(8, templatefile("${path.module}/argocd-addons/slinky-slurm/slurm-values.yaml", {
      image_repository = var.image_repository
      image_tag        = var.image_tag
      ssh_key          = var.ssh_key
    }))
  })

  depends_on = [
    module.eks_blueprints_addons,
    kubectl_manifest.slurm_operator_yaml,
    kubectl_manifest.priority_class
  ]
}
