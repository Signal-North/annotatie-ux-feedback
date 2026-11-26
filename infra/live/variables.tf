variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "domain_name" {
  description = "The platform's hostname (no default: the bootstrap writes it to the DOMAIN_NAME variable)."
  type        = string
}

variable "route53_zone" {
  description = "The existing public Route 53 hosted zone that holds domain_name. Only one record is added to it."
  type        = string
}

variable "certificate_domain" {
  description = "Primary domain of the existing ISSUED us-east-1 ACM certificate covering domain_name. null = route53_zone."
  type        = string
  default     = null
}

variable "build_sha" {
  description = "The commit being deployed; shown by /api/health."
  type        = string
  default     = "dev"
}

variable "dist_dir" {
  description = "Where `npm run build` put its output, relative to this root."
  type        = string
  default     = "../../dist"
}

variable "alarm_email" {
  description = "Where alarms go. Empty = alarms exist but notify nobody."
  type        = string
  default     = ""
}

variable "api_reserved_concurrency" {
  description = "Hard ceiling on concurrent API Lambdas (free). null = none; new accounts with a 10 limit can't reserve."
  type        = number
  default     = null
}

variable "auto_approve_allowed" {
  description = "Kill switch: false stops every site's auto-approve at once (agent replies always wait for a person)."
  type        = bool
  default     = true
}
