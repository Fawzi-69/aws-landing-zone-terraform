config {
  call_module_type = "all"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.43.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Naming convention: snake_case for all blocks.
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Require a description on every variable and output.
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# Enforce explicit type on variables.
rule "terraform_typed_variables" {
  enabled = true
}

# Pin module + provider versions.
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
