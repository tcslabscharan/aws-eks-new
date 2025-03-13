# Add variable for additional admin users/roles
variable "eks_admin_arns" {
  description = "List of IAM ARNs to be added as EKS admins (in addition to the cluster creator)"
  type        = list(string)
  default     = []
}

# Create aws-auth ConfigMap using the aws_eks_identity_provider_config approach
# Generate aws-auth config content as an output instead of local file
output "aws_auth_configmap" {
  description = "The aws-auth ConfigMap content"
  value = templatefile("${path.module}/templates/aws-auth-cm.tpl", {
    node_role_arn = aws_iam_role.eks_node_group.arn,
    fargate_role_arn = aws_iam_role.eks_fargate.arn,
    admin_arns = var.eks_admin_arns
  })
}

# Write the aws-auth ConfigMap to a file
resource "local_file" "aws_auth_configmap" {
  content  = templatefile("${path.module}/templates/aws-auth-cm.tpl", {
    node_role_arn = aws_iam_role.eks_node_group.arn,
    fargate_role_arn = aws_iam_role.eks_fargate.arn,
    admin_arns = var.eks_admin_arns
  })
  filename = "${path.module}/aws-auth-cm.yaml"
}

# Output the command to apply the auth ConfigMap manually
output "apply_auth_config_cmd" {
  description = "Command to apply the auth ConfigMap"
  value       = "kubectl apply -f ${path.module}/aws-auth-cm.yaml"
}

# Output for kubectl configuration command
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region}"
}

# Output command for updating aws-auth with required permissions
output "update_aws_auth_command" {
  description = "Commands to update aws-auth ConfigMap"
  value = <<EOT
# First configure kubectl:
aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region}

# Then apply the aws-auth ConfigMap:
kubectl apply -f ${path.module}/aws-auth-cm.yaml
EOT
}