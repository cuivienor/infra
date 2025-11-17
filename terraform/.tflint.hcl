# TFLint configuration for homelab Terraform code
# https://github.com/terraform-linters/tflint

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Enforce naming conventions
rule "terraform_naming_convention" {
  enabled = true
}

# Require version constraints for providers
rule "terraform_required_providers" {
  enabled = true
}

# Require version constraints for Terraform
rule "terraform_required_version" {
  enabled = true
}

# Disallow legacy dot index syntax
rule "terraform_deprecated_index" {
  enabled = true
}

# Disallow empty list items
rule "terraform_empty_list_equality" {
  enabled = true
}

# Require module version to be specified
rule "terraform_module_version" {
  enabled = true
}

# Disallow comparisons with bool
rule "terraform_typed_variables" {
  enabled = true
}

# Suggest using count for single resource iteration
rule "terraform_unused_declarations" {
  enabled = true
}

# Warn about unused variable declarations
rule "terraform_unused_required_providers" {
  enabled = true
}

# Standardize on snake_case for naming
rule "terraform_standard_module_structure" {
  enabled = true
}

# Comment descriptions for variables
rule "terraform_documented_variables" {
  enabled = true
}

# Comment descriptions for outputs
rule "terraform_documented_outputs" {
  enabled = true
}
