variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type        = string
  description = "Prefixo dos recursos da API de frota da Vortex."
  default     = "vortex-frota"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "vortex-mobility"
      ManagedBy = "terraform"
      Lab       = "03-cicd"
    }
  }
}

# Conta atual: usamos o LabRole (unica role utilizavel no Academy) como execution
# role da Lambda, em vez de criar uma role nova (proibido no Learner Lab).
data "aws_caller_identity" "current" {}
