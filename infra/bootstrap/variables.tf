variable "aws_region" {
  description = "Region for everything regional (CloudFront certificates still go to us-east-1)."
  type        = string
  default     = "eu-west-2"
}

variable "expected_account_id" {
  description = "The target AWS account. The apply refuses to run against any other account."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account id."
  }
}

variable "github_owner" {
  description = "GitHub user or organisation that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "Repository name."
  type        = string
  default     = "annotatie"
}

variable "create_github_repo" {
  description = "Create the repository with OpenTofu. Set false if it already exists (it is then read, not managed)."
  type        = bool
  default     = true
}

variable "enable_branch_protection" {
  description = "Protect main (needs GitHub Pro/Team for a private repository on a personal account)."
  type        = bool
  default     = false
}

variable "budget_email" {
  description = "Where AWS Budget alerts go."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget that triggers alerts (C-16)."
  type        = number
  default     = 5
}

variable "budget_filter_by_project_tag" {
  description = "Measure only spend tagged project = annotatie (needed in a shared account; activate the tag in Billing)."
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "The platform's hostname, inside route53_zone."
  type        = string
}

variable "route53_zone" {
  description = "The existing public Route 53 hosted zone that holds domain_name. The deploy role may change only that one A record in it."
  type        = string
}

variable "certificate_domain" {
  description = "Primary domain of the existing ISSUED us-east-1 ACM certificate covering domain_name. null = route53_zone."
  type        = string
  default     = null
}

variable "create_github_oidc_provider" {
  description = "Create the account's GitHub OIDC provider. Set false when the account already has one (it is then read, not managed)."
  type        = bool
  default     = true
}
