data "aws_availability_zones" "available" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name                = try(trim(format("%v-%v-%v", var.owner, var.cluster_name, random_id.eks_cluster_name_suffix.hex), 28))
  current_k8s_version = try(var.kubernetes_version, "")
  vpc_cidr            = "10.0.0.0/16"
  zones               = slice(data.aws_availability_zones.available.names, 0, var.max_availability_zones)
  account_id          = data.aws_caller_identity.current.account_id
}

# Random identifier for cluster name suffix
resource "random_id" "eks_cluster_name_suffix" {
  byte_length = 3
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.19.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.zones
  public_subnets  = [for k, v in local.zones : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.zones : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_ipv6                     = true
  assign_ipv6_address_on_creation = true
  create_egress_only_igw          = true

  public_subnet_ipv6_prefixes  = var.public_subnet_ipv6_prefixes
  private_subnet_ipv6_prefixes = var.private_subnet_ipv6_prefixes

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.10.0"

  cluster_name                   = local.name
  cluster_version                = local.current_k8s_version
  cluster_endpoint_public_access = true

  cluster_ip_family = "ipv6"
  # Created externally due to https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2131
  create_cni_ipv6_iam_policy = var.create_cni_ipv6_iam_policy

  create_cluster_primary_security_group_tags = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  # Enable IRSA
  enable_irsa = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    initial = {
      use_name_prefix          = false
      iam_role_use_name_prefix = false
    }
  }
  eks_managed_node_groups = {
    initial = {
      name           = try(format("%v-ng", trim(local.name, 25)))
      iam_role_name  = try(format("%v-ng", trim(local.name, 25)))
      instance_types = [var.node_type]

      min_size     = var.min_nodes
      max_size     = var.max_nodes
      desired_size = var.nodes
    }
  }

  tags = var.tags
}

# ------------------------------ Security groups --------------------------------------
resource "aws_security_group_rule" "allow_istio_mutation_webhook" {
  count = var.allow_istio_mutation_webhook_sg ? 1 : 0

  type                     = "ingress"
  security_group_id        = module.eks.node_security_group_id
  description              = "Allow Istio mutation webhook (This allows Kubernetes admission controller access)"
  from_port                = 15017
  to_port                  = 15017
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
}
# -------------------------------------------------------------------------------------

# ------------------------------ IAM Role for ELB -------------------------------------
resource "aws_iam_policy" "alb_ingress_controller_iam_policy" {
  name        = try(format("%v-ALBIngressControllerIAMPolicy", local.name))
  description = "Policy which will be used by role for service - for creating alb from within cluster by issuing declarative kube commands"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:GetSubscriptionState",
                "shield:DescribeProtection",
                "shield:CreateProtection",
                "shield:DeleteProtection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "StringEquals": {
                    "elasticloadbalancing:CreateAction": [
                        "CreateTargetGroup",
                        "CreateLoadBalancer"
                    ]
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule"
            ],
            "Resource": "*"
        }
    ]
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "alb-ingress-controller-role" {
  name = try(format("%v-alb", local.name))

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${module.eks.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${module.eks.oidc_provider}:sub": "system:serviceaccount:kube-system:alb-ingress-controller",
          "${module.eks.oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
POLICY

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [module.eks]

  tags = merge(
    var.tags,
    {
      "ServiceAccountName"      = "alb-ingress-controller"
      "ServiceAccountNameSpace" = "kube-system"
    }
  )
}

resource "aws_iam_role_policy_attachment" "alb-ingress-controller-role-ingress-controller-attachment" {
  role       = aws_iam_role.alb-ingress-controller-role.name
  policy_arn = aws_iam_policy.alb_ingress_controller_iam_policy.arn

  depends_on = [aws_iam_role.alb-ingress-controller-role]
}

resource "aws_iam_role_policy_attachment" "alb-ingress-controller-role-AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.alb-ingress-controller-role.name
  policy_arn = "arn:aws:iam::${local.account_id}:policy/AmazonEKS_CNI_IPv6_Policy"

  depends_on = [aws_iam_role.alb-ingress-controller-role]
}
# -------------------------------------------------------------------------------------
