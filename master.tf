locals {
  tgw_name = try(format("%v-tgw", var.owner))
  tags = merge(
    {
      "created-by" = var.owner
      "team"       = var.team
      "purpose"    = var.purpose
      "component"  = var.component
      "managed-by" = "terraform"
    },
    var.extra_tags
  )
}

module "eks_ipv6_1" {
  source = "./modules/eks-ipv6"

  owner                      = var.owner
  region                     = var.region
  max_availability_zones     = var.max_availability_zones_per_cluster
  kubernetes_version         = var.kubernetes_version
  create_cni_ipv6_iam_policy = true

  tags = local.tags
}

module "eks_ipv6_2" {
  source = "./modules/eks-ipv6"

  owner                           = var.owner
  region                          = var.region
  max_availability_zones          = var.max_availability_zones_per_cluster
  kubernetes_version              = var.kubernetes_version
  create_cni_ipv6_iam_policy      = false
  allow_istio_mutation_webhook_sg = true
  ec2_ssh_key                     = var.ec2_ssh_key
  enable_bastion                  = true

  tags = local.tags
}

module "eks_ipv6_3" {
  source = "./modules/eks-ipv6"

  owner                           = var.owner
  region                          = var.region
  max_availability_zones          = var.max_availability_zones_per_cluster
  kubernetes_version              = var.kubernetes_version
  create_cni_ipv6_iam_policy      = false
  allow_istio_mutation_webhook_sg = true

  tags = local.tags
}

module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "~> 2.10.0"

  name = local.tgw_name

  # Only on a single account
  enable_auto_accept_shared_attachments = false

  # When "true", allows service discovery through IGMP
  enable_multicast_support = false

  enable_dns_support = true

  # Dont share with other accounts
  share_tgw = false

  vpc_attachments = {
    vpc1 = {
      vpc_id     = module.eks_ipv6_1.vpc_id
      subnet_ids = module.eks_ipv6_1.private_subnets

      dns_support             = true
      ipv6_support            = true
      appliance_mode_support  = false
      enable_vpn_ecmp_support = false

      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true
    },
    vpc2 = {
      vpc_id     = module.eks_ipv6_2.vpc_id
      subnet_ids = module.eks_ipv6_2.private_subnets

      dns_support             = true
      ipv6_support            = true
      appliance_mode_support  = false
      enable_vpn_ecmp_support = false
    }
    vpc3 = {
      vpc_id     = module.eks_ipv6_3.vpc_id
      subnet_ids = module.eks_ipv6_3.private_subnets

      dns_support             = true
      ipv6_support            = true
      appliance_mode_support  = false
      enable_vpn_ecmp_support = false
    }
  }

  depends_on = [
    module.eks_ipv6_1,
    module.eks_ipv6_2,
    module.eks_ipv6_3
  ]

  tags = local.tags
}

resource "aws_route" "eks_ipv6_1_2_rt" {
  count = length(module.eks_ipv6_1.private_route_table_ids)

  route_table_id              = element(module.eks_ipv6_1.private_route_table_ids, count.index)
  destination_ipv6_cidr_block = module.eks_ipv6_2.vpc_ipv6_cidr_block
  transit_gateway_id          = module.tgw.ec2_transit_gateway_id
}

resource "aws_route" "eks_ipv6_1_3_rt" {
  count = length(module.eks_ipv6_1.private_route_table_ids)

  route_table_id              = element(module.eks_ipv6_1.private_route_table_ids, count.index)
  destination_ipv6_cidr_block = module.eks_ipv6_3.vpc_ipv6_cidr_block
  transit_gateway_id          = module.tgw.ec2_transit_gateway_id
}

resource "aws_route" "eks_ipv6_2_1_rt" {
  count = length(module.eks_ipv6_2.private_route_table_ids)

  route_table_id              = element(module.eks_ipv6_2.private_route_table_ids, count.index)
  destination_ipv6_cidr_block = module.eks_ipv6_1.vpc_ipv6_cidr_block
  transit_gateway_id          = module.tgw.ec2_transit_gateway_id
}

resource "aws_route" "eks_ipv6_2_3_rt" {
  count = length(module.eks_ipv6_2.private_route_table_ids)

  route_table_id              = element(module.eks_ipv6_2.private_route_table_ids, count.index)
  destination_ipv6_cidr_block = module.eks_ipv6_3.vpc_ipv6_cidr_block
  transit_gateway_id          = module.tgw.ec2_transit_gateway_id
}

resource "aws_route" "eks_ipv6_3_1_rt" {
  count = length(module.eks_ipv6_3.private_route_table_ids)

  route_table_id              = element(module.eks_ipv6_3.private_route_table_ids, count.index)
  destination_ipv6_cidr_block = module.eks_ipv6_1.vpc_ipv6_cidr_block
  transit_gateway_id          = module.tgw.ec2_transit_gateway_id
}

resource "aws_route" "eks_ipv6_3_2_rt" {
  count = length(module.eks_ipv6_3.private_route_table_ids)

  route_table_id              = element(module.eks_ipv6_3.private_route_table_ids, count.index)
  destination_ipv6_cidr_block = module.eks_ipv6_2.vpc_ipv6_cidr_block
  transit_gateway_id          = module.tgw.ec2_transit_gateway_id
}
