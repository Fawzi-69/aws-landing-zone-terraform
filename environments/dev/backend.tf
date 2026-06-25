terraform {
  # Partial backend — see backend.hcl.example. Only the per-root state key is
  # fixed here; bucket / table / region / kms come from -backend-config.
  backend "s3" {
    key = "environments/dev/terraform.tfstate"
  }
}
