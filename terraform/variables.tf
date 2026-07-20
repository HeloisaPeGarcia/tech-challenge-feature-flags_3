variable "aws_region" {
  type        = string
  description = "Região da AWS para provisionamento"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Ambiente (dev, prod, etc)"
  default     = "dev"
}

variable "use_aws_academy" {
  type        = bool
  description = "Se true, utiliza a LabRole existente da AWS Academy para o EKS. Se false, cria novas Roles/Policies de IAM."
  default     = true
}

variable "aws_academy_labrole_name" {
  type        = string
  description = "Nome da LabRole existente na AWS Academy"
  default     = "LabRole"
}
