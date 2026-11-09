variable "region" {
  type    = string
  default = "us-east-1"
}

variable "owner" { type = string }

variable "github_repo" {
  type        = string
  description = "owner/repo that Argo CD syncs from, e.g. mk7git-hub/k8s-gitops-platform"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "4 GB RAM fits k3s, Argo CD and Kyverno. About $1 a day."
}

variable "k3s_version" {
  type    = string
  default = "v1.30.6+k3s1"
}

variable "argocd_version" {
  type    = string
  default = "v2.12.6"
}

variable "kyverno_version" {
  type        = string
  default     = "3.2.8"
  description = "Kyverno Helm chart version"
}
