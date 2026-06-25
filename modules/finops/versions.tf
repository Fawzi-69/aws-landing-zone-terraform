terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
      # AWS Budgets and Cost Explorer (anomaly detection) are global services
      # reachable only through the us-east-1 endpoint, and budget SNS topics
      # must live there too. Callers pass a us-east-1 provider as aws.billing.
      configuration_aliases = [aws.billing]
    }
  }
}
