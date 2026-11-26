# The edge in an account that already owns its DNS zone and certificate: both are looked up, never
# created. The CloudFront certificate is an existing ISSUED ACM certificate in us-east-1 (pass the
# us-east-1 provider as "aws"); the hostname's record goes into an existing public Route 53 zone.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "domain_name" {
  type = string
}

variable "route53_zone" {
  description = "The existing public Route 53 hosted zone that holds domain_name (no zone is created)."
  type        = string
}

variable "certificate_domain" {
  description = "The primary domain of the existing us-east-1 ACM certificate that covers domain_name."
  type        = string
}

data "aws_acm_certificate" "this" {
  domain      = var.certificate_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "this" {
  name         = var.route53_zone
  private_zone = false
}

output "certificate_arn" {
  value = data.aws_acm_certificate.this.arn
}

output "route53_zone_id" {
  value = data.aws_route53_zone.this.zone_id
}
