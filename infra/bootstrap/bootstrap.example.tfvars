# Copy to bootstrap.tfvars (git-ignored) and fill in. Nothing here is secret.
expected_account_id = "123456789012"
github_owner        = "your-github-user"
budget_email        = "you@example.com"
domain_name         = "feedback.example.com" # inside route53_zone, covered by the certificate
route53_zone        = "example.com"          # an existing public hosted zone; only one A record is added
# certificate_domain          = "example.com" # existing ISSUED us-east-1 ACM certificate; default = route53_zone
# aws_region                  = "eu-west-2"
# create_github_oidc_provider = false         # the account already has token.actions.githubusercontent.com
# budget_filter_by_project_tag = true         # activate the project tag in Billing for it to count
# enable_branch_protection    = false         # true needs GitHub Pro/Team for a private repo
