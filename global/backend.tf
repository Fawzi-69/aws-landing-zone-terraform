terraform {
  # Partial backend: bucket / dynamodb_table / region / kms_key_id are supplied
  # at init time via `-backend-config` (see backend.hcl.example). Only the state
  # key, which is fixed per root, lives here.
  backend "s3" {
    key = "global/terraform.tfstate"
  }
}
