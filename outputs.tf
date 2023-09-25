output "eks_ipv6_1_k8_cluster_name" {
  value       = "${module.eks_ipv6_1.cluster_name}"
}

output "eks_ipv6_2_k8_cluster_name" {
  value       = "${module.eks_ipv6_2.cluster_name}"
}

output "eks_ipv6_3_k8_cluster_name" {
  value       = "${module.eks_ipv6_3.cluster_name}"
}

output "eks_ipv6_1_k8_kubeconfig" {
  value = "${module.eks_ipv6_1.kubeconfig_path}"
}

output "eks_ipv6_1_k8_kubeconfig_context" {
  value = "${module.eks_ipv6_1.kubeconfig_context}"
}

output "eks_ipv6_2_k8_kubeconfig" {
  value = "${module.eks_ipv6_2.kubeconfig_path}"
}

output "eks_ipv6_2_k8_kubeconfig_context" {
  value = "${module.eks_ipv6_2.kubeconfig_context}"
}

output "eks_ipv6_3_k8_kubeconfig" {
  value = "${module.eks_ipv6_3.kubeconfig_path}"
}

output "eks_ipv6_3_k8_kubeconfig_context" {
  value = "${module.eks_ipv6_3.kubeconfig_context}"
}

output "eks_ipv6_1_k8_kubectl" {
  value       = "${module.eks_ipv6_1.configure_kubectl}"
}

output "eks_ipv6_2_k8_kubectl" {
  value       = "${module.eks_ipv6_2.configure_kubectl}"
}

output "eks_ipv6_3_k8_kubectl" {
  value       = "${module.eks_ipv6_3.configure_kubectl}"
}