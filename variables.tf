# ----------------------------------------------------------------------------------
# Common properties
# ----------------------------------------------------------------------------------

variable "owner" {
  description = "Name of the maintainer of the cluster"
  type        = string

  validation {
    condition     = can(length(var.owner) > 0)
    error_message = "Maintainer of the cluster must be provided."
  }
}

variable "team" {
  description = "Team that maintains the cluster"
  type        = string
  default     = "fe-presale"
}

variable "purpose" {
  description = "Purpose for the cluster"
  type        = string
  default     = "pre-sales"
}

variable "component" {
  description = "Product type"
  type        = string
  default     = "gloo-platform"
}

variable "extra_tags" {
  description = "Tags used for the EKS resources"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------------
# AWS EKS properties
# ----------------------------------------------------------------------------------

variable "region" {
  description = "AWS region for EKS (Default: `ap-southeast-2`, Ref: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html)"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS cli profile (Default: `default`)"
  type        = string
  default     = "default"
}

variable "max_availability_zones_per_cluster" {
  description = "Maximum number of availability zones per cluster"
  type        = number
  default     = 2
}

variable "kubernetes_version" {
  description = "Kubernetes version. If not specified the current stable version is used"
  type        = string
  default     = null
}

variable "ec2_ssh_key" {
  description = "SSH key name that should be used to access the instances"
  type        = string
  default     = null
}
