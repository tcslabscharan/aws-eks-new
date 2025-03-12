# AWS-EKS deployment
Run terraform plan and apply.    
you can change values from terraform.tfvars   
to get the eks credentials use:
```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>

e.g.

aws eks update-kubeconfig --name eks-prod --region us-east-1 
```

### expose service type as load balancer
for the fargate service use some annotations
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"  # For Fargate
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"  
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: nginx
  type: LoadBalancer
```

### Use of pod identity mapping 
Bellow is not part of the terraform eks folder. You can add based on your requirements.
```hcl
# IAM Role for the Pod Identity Association
resource "aws_iam_role" "pod_identity_role" {
  name = "eks-pod-identity-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
    }]
  })

  # Example permissions - customize based on your needs
  # This example allows S3 read access
  inline_policy {
    name = "s3-read-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Effect   = "Allow"
          Resource = [
            "arn:aws:s3:::example-bucket",
            "arn:aws:s3:::example-bucket/*"
          ]
        }
      ]
    })
  }

  tags = {
    Name = "eks-pod-identity-role-${random_string.suffix.result}"
  }
}

# Create EKS Pod Identity Association
resource "aws_eks_pod_identity_association" "default_aws_sa" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "default"
  service_account = "aws-sa"
  role_arn        = aws_iam_role.pod_identity_role.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
}

# Output for Pod Identity Association
output "pod_identity_association_id" {
  description = "ID of the Pod Identity Association"
  value       = aws_eks_pod_identity_association.default_aws_sa.id
}
```
example k8s resource
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-sa
  namespace: default

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aws-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aws-app
  template:
    metadata:
      labels:
        app: aws-app
    spec:
      serviceAccountName: aws-sa  # This links to the service account with Pod Identity
      containers:
      - name: aws-app
        image: amazon/aws-cli:latest
        command: ["sleep", "infinity"]
```