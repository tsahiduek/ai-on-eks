resource "time_sleep" "wait_for_slurm_service" {
  count           = var.deploy_slurm_cluster ? 1 : 0
  create_duration = "60s"
  
  depends_on = [
    kubectl_manifest.slurm_cluster_yaml
  ]
}

resource "kubernetes_annotations" "slurm_login_service" {
  count       = var.deploy_slurm_cluster ? 1 : 0
  api_version = "v1"
  kind        = "Service"
  metadata {
    name      = "slurm-login"
    namespace = "slurm"
  }
  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type"              = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-scheme"            = "internet-facing"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"   = "ip"
    "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"  = "22"
  }

  depends_on = [
    time_sleep.wait_for_slurm_service
  ]
}
