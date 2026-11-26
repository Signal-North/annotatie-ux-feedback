# Annotatie

Users pin feedback to the exact part of a page. AI agents read it through MCP and draft replies.
**Nothing an agent writes reaches a user until a person approves it in the portal**, unless that site's
auto-approve flag is on. Design and plan: [`docs/implementation-plan.md`](docs/implementation-plan.md);
costs: [`docs/cost-register.md`](docs/cost-register.md).

**Phase P0 (this commit):** the repository, the pipeline and the cost proof. It contains a health-check
API Lambda behind CloudFront at `https://annotatie.consulteasy.co.uk`, a placeholder portal page, and a
cost guard that fails any plan adding a resource with a fixed monthly fee.

## Layout

| Path | What |
|---|---|
| `services/api` | API Lambda (P0: `GET /api/health`) |
| `apps/portal` | Portal (P0: a placeholder page at `/board/`) |
| `tools/cost-guard` | Fails a plan that adds fixed-cost resources (KMS keys, NAT, WAF, …) |
| `bin/toolbox`, `tools/toolbox` | Runs `tofu`, `gh` and `aws` in Docker, so none of them is installed locally |
| `infra/bootstrap` | Run **once, locally**: state bucket, GitHub OIDC, CI roles, the GitHub repo, environment and variables, budget |
| `infra/live` | Applied by CI on every merge to `main` |
| `infra/modules` | `edge` (looks up the existing ACM certificate and Route 53 zone), `static`, `api`, `cdn`, `observability` |

## Develop

```bash
npm ci && npm run typecheck && npm test && npm run build
```

## Secrets: where each one lives

**GitHub holds none.** AWS access is by OIDC, and DNS is Route 53 in the same account, so there is no DNS
token anywhere. PR plans use a read-only role; only deploys from `main` may change the one DNS record.

## One-time setup (about 15 minutes)

You need Docker, an AWS profile that is an admin **of the target account**, and in that account a public
**Route 53 hosted zone** holding your hostname and an **ISSUED ACM certificate in `us-east-1`** that covers
it (both are looked up, never created). Nothing else is installed: `bin/toolbox` runs OpenTofu 1.10.10 (the CI version),
the GitHub CLI and the AWS CLI in a container, from the folder you are in. Run it from Git Bash on Windows.
It mounts your `~/.aws`; the GitHub login stays in the Docker volume `annotatie-gh`. Set the profile first:

```bash
export AWS_PROFILE=<target-account profile> AWS_REGION=eu-west-2
```

```bash
bin/toolbox aws sts get-caller-identity
```

```bash
bin/toolbox gh auth login
```

**1. Check the zone and the certificate** (both must already exist):

```bash
bin/toolbox aws route53 list-hosted-zones-by-name --dns-name <your zone> --max-items 1
```

```bash
bin/toolbox aws acm list-certificates --region us-east-1 --certificate-statuses ISSUED
```

**2. Check for an existing GitHub OIDC provider.** An account holds one per URL. If this lists
`token.actions.githubusercontent.com`, set `create_github_oidc_provider = false` in step 3:

```bash
bin/toolbox aws iam list-open-id-connect-providers
```

**3. Bootstrap** (creates the GitHub repo too):

```bash
cd infra/bootstrap && cp bootstrap.example.tfvars bootstrap.tfvars   # account id, GitHub owner, email, domain, zone
```

The state bucket does not exist yet, so the first apply keeps its state locally. A git-ignored
`first_run_override.tf` swaps the S3 backend for a local one for this run only:

```bash
printf 'terraform {\n  backend "local" {}\n}\n' > first_run_override.tf
```

```bash
../../bin/toolbox sh -c 'GITHUB_TOKEN=$(gh auth token) && tofu init && tofu apply -var-file=bootstrap.tfvars'
```

**4. Move the bootstrap state into its bucket.** Write the `backend_hcl` output to
`infra/bootstrap/backend.hcl` (while the local backend is still in force), delete `first_run_override.tf`,
then migrate:

```bash
../../bin/toolbox sh -c 'tofu output -raw backend_hcl > backend.hcl' && rm first_run_override.tf
```

```bash
../../bin/toolbox tofu init -migrate-state -force-copy -backend-config=backend.hcl
```

**5. Push.** The first push to `main` deploys:

```bash
git remote add origin git@github.com:<owner>/annotatie.git && git push -u origin main
```

**6. Confirm** the AWS Budget and SNS alarm emails (one click each), then open
`https://annotatie.consulteasy.co.uk/board/`. It shows the deployed commit.

## Deploy your own copy

The workflows contain nothing specific to one AWS account or domain. Everything comes from repository
variables that the bootstrap writes, so a fork deploys to your own infrastructure without code changes:

1. Fork this repository. Until step 3 is done, `deploy` only prints a notice and the CI `infra` plan is
   skipped; nothing tries to reach AWS.
2. **Enable Actions on the fork** (Settings → Actions → General; forks start with Actions disabled).
3. Follow **One-time setup** above against your own AWS account. In `bootstrap.tfvars` also set:
   ```hcl
   github_owner       = "<your GitHub user or org>"
   github_repo        = "<your fork's name>"
   create_github_repo = false                     # the fork already exists
   domain_name        = "feedback.example.com"    # inside route53_zone
   route53_zone       = "example.com"             # existing public hosted zone
   # certificate_domain = "example.com"           # existing ISSUED us-east-1 certificate; default = route53_zone
   ```
   The bootstrap trusts only your fork for OIDC and writes its Actions variables (`AWS_ACCOUNT_ID`,
   `AWS_REGION`, `DOMAIN_NAME`, `ROUTE53_ZONE`, `CERTIFICATE_DOMAIN`, …).

   **In an account shared with other workloads:**
   - nothing account-wide is created except the GitHub OIDC provider, and only when the account has none
     (`create_github_oidc_provider = false` reuses an existing one);
   - the deploy role may change exactly one record in the zone, the `A` record for `domain_name`; the zone,
     its other records and the certificate are read only;
   - the budget counts only spend tagged `project = annotatie` (`budget_filter_by_project_tag`, default
     on). Activate `project` as a cost-allocation tag in Billing → Cost allocation tags; it is listed there
     only once tagged resources exist, and the budget reads $0 until it is active.
4. Push to (or merge into) your fork's `main`. It deploys to your account.

To take later updates, sync your fork with this repository. Keep your changes out of tracked files where
you can (they belong in `bootstrap.tfvars` and the repository variables), and syncing stays conflict-free.

## Cost proof (end of P0)

Leave it running for a week, then check Cost Explorer filtered by the tag `project = annotatie`. The
expected total is **≈ $0.00–$0.05**. The budget alert fires at $2.50 actual and at $5 forecast.

## License

Copyright (c) 2026 ConsultEZ. Released under the [MIT License](LICENSE).

You are free to use, copy, modify, fork, self-host and redistribute this code,
including commercially, as long as the copyright and licence notice stay with
it. ConsultEZ maintains this repository and decides what goes into it; forks
are welcome to go their own way.
