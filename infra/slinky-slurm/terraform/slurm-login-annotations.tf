resource "null_resource" "wait_for_slurm_login_service" {
  count = var.enable_slurm_cluster ? 1 : 0

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = pathexpand("~/.kube/config")
    }
    command = <<-EOT
      aws eks --region ${var.region} update-kubeconfig --name ${var.name}
      attempts=0
      until kubectl get service slurm-login -n slurm; do
        attempts=$((attempts + 1))
        if [ $attempts -ge 30 ]; then
          echo "Timeout waiting for slurm-login service"
          exit 1
        fi
        echo "Waiting for slurm-login service... attempt $attempts"
        sleep 10
      done
    EOT
  }

  depends_on = [
    kubectl_manifest.slurm_cluster_yaml
  ]
}

resource "kubernetes_annotations" "slurm_login_service" {
  count       = var.enable_slurm_cluster ? 1 : 0
  api_version = "v1"
  kind        = "Service"
  metadata {
    name      = "slurm-login"
    namespace = "slurm"
  }
  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type"                    = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-scheme"                  = "internet-facing"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"         = "ip"
    "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"        = "22"
    "service.beta.kubernetes.io/aws-load-balancer-target-group-attributes" = "preserve_client_ip.enabled=true"
    "service.beta.kubernetes.io/load-balancer-source-ranges"               = ""
  }

  depends_on = [
    null_resource.wait_for_slurm_login_service
  ]
}
