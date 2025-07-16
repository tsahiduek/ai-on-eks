resource "kubectl_manifest" "priority_class" {
count       = var.deploy_slurm_cluster ? 1 : 0
yaml_body   = <<YAML
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: slurm-node-priority
value: 0
globalDefault: false
description: "Priority class for Slurm Compute NodeSet"
YAML
  
  depends_on = [module.eks.eks_cluster_id]
}
