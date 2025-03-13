apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${node_role_arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${fargate_role_arn}
      username: system:node:{{SessionName}}
      groups:
        - system:bootstrappers
        - system:nodes
        - system:node-proxier
  mapUsers: |
%{ for arn in admin_arns ~}
    - userarn: ${arn}
      username: ${split("/", arn)[1]}
      groups:
        - system:masters
%{ endfor ~}
