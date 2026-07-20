terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # O backend S3 é configurado dinamicamente via -backend-config no CI/CD.
  # O bucket e a tabela DynamoDB são criados automaticamente pelo workflow
  # antes do terraform init ser executado.
  # Para executar LOCAL, passe os valores diretamente:
  #   terraform init \
  #     -backend-config="bucket=SEU-BUCKET" \
  #     -backend-config="key=dev/terraform.tfstate" \
  #     -backend-config="region=us-east-1" \
  #     -backend-config="dynamodb_table=terraform-lock-table"
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}
