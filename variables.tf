variable "namespace" {
  type    = string
  default = "anchore-engine"
}

variable "dns_zone" {
  type    = string
  default = "opencloudcx.internal"
}

variable "admin_email" {
  type = string
}

variable "helm_chart" {
  type    = string
  default = "https://charts.anchore.io"
}

variable "helm_chart_name" {
  type    = string
  default = "anchore-engine"
}

variable "helm_version" {
  type    = string
  default = "1.15.1"
}

variable "helm_timeout" {
  description = "Timeout value to wait for helm chart deployment"
  type        = number
  default     = 600
}
