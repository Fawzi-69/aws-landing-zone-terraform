terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
      # This module spans two accounts: the management account owns the
      # organization trail, the log-archive account owns the destination
      # bucket + KMS key. Callers must pass both aliased providers.
      configuration_aliases = [aws.management, aws.log_archive]
    }
  }
}
