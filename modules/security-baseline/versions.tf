terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
      # Detective controls are delegated from the management account to the
      # security account (delegated administrator pattern).
      configuration_aliases = [aws.management, aws.security]
    }
  }
}
