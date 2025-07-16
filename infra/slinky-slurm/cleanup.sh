#!/bin/bash
kubectl get service slurm-login -n slurm >/dev/null 2>&1 && \
kubectl patch service slurm-login -n slurm -p '{"spec":{"type":"ClusterIP"}}' || true

cd terraform/_LOCAL/

# REGION="$(echo "var.region" | terraform console -var-file=../blueprint.tfvars | tr -d '"')"

# echo "Destroying Slurm login Load Balancer..."
# for arn in $(aws resourcegroupstaggingapi get-resources \
#   --resource-type-filters elasticloadbalancing:loadbalancer \
#   --tag-filters "Key=kubernetes.io/service-name,Values=slurm/slurm-login" \
#   --query 'ResourceTagMappingList[].ResourceARN' \
#   --region $REGION \
#   --output text 2>/dev/null || true); do \
#     if [[ "$arn" == *"/net/"* ]] || [[ "$arn" == *"/app/"* ]]; then
#       # Network/Application Load Balancer (ELBv2)
#       echo "Found NLB: $arn";
#       for sg_id in $(aws elbv2 describe-load-balancers --region $REGION --load-balancer-arns "$arn" \
#         --query 'LoadBalancers[0].SecurityGroups[]' --output text 2>/dev/null || true); do \
#           echo "Deleting NLB SG: $sg_id"; \
#           aws ec2 delete-security-group --no-cli-pager --region $REGION --group-id "$sg_id" || true; \
#         done
#       for tg_arn in $(aws elbv2 describe-target-groups --region $REGION --load-balancer-arn "$arn" \
#         --query 'TargetGroups[].TargetGroupArn' --output text 2>/dev/null || true); do \
#           echo "Deleting NLB TG: $tg_arn"; \
#           aws elbv2 delete-target-group --region $REGION --target-group-arn "$tg_arn" || true; \
#         done
#       echo "Deleting NLB: $arn"; \
#       aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn "$arn" || true
#     else
#       # Classic Load Balancer (ELB)
#       echo "Found ELB: $arn"
#       lb_name=$(echo "$arn" | cut -d'/' -f2)
#       for sg_id in $(aws elb describe-load-balancers --region $REGION --load-balancer-names "$lb_name" \
#         --query 'LoadBalancerDescriptions[0].SecurityGroups[]' --output text 2>/dev/null || true); do \
#           echo "Deleting ELB SG: $sg_id"; \
#           aws ec2 delete-security-group --no-cli-pager --region $REGION --group-id "$sg_id" || true; \
#         done
#       echo "Deleting ELB: $arn"; \
#       aws elb delete-load-balancer --region $REGION --load-balancer-name "$lb_name" || true
#     fi
#   done

./cleanup.sh