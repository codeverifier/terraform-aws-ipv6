# Terraform AWS IPv6

Terraform project for provisioning IPv6 clusters in AWS.
It follows the architecture below to provision the clusters in a hub-spoke topology.

<img src="https://user-images.githubusercontent.com/2648624/224839862-5885768d-648d-421c-bee6-b38903af9027.png" width="50%" height="50%" alt="Hub-and-spoke topology">

## Instructions

Variables can be provided via `terraform.tfvars`. Refer to the example below,

```
owner = "joe.blogg"

aws_profile = "default"
region      = "ap-southeast-1"

max_availability_zones_per_cluster = 2
kubernetes_version                 = "1.24"
```

`terraform output` will show how to inject the kubeconfig configuration.
