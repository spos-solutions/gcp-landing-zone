# GCP Naming Convention - Quick Reference

## Core Patterns

### Projects
```
prj-{env}-{purpose}-{identifier}
```
- **env**: b=bootstrap, d=dev, s=staging, p=prod
- **Examples**: `prj-b-seed-spos`, `prj-p-app-web`

### Service Accounts
```
sa-{purpose}-{env}@{project}.iam.gserviceaccount.com
```
- **Examples**: `sa-terraform-bootstrap@prj-b-seed-spos.iam.gserviceaccount.com`

### Buckets
```
bkt-{project_prefix}-{purpose}
```
- **Examples**: `bkt-prj-b-seed-tfstate`, `bkt-prj-p-app-logs`

### WIF Pools
```
{env}-{source}-pool
```
- **Examples**: `bootstrap-gh-pool`, `production-k8s-pool`

### WIF Providers
```
{env}-{source}-provider
```
- **Examples**: `bootstrap-gh-provider`, `production-aws-provider`

## Environment Codes
- `b` = Bootstrap
- `d` = Development
- `s` = Staging
- `p` = Production
- `q` = QA
- `u` = UAT

## Region Codes
- `na-ne1` = northamerica-northeast1
- `us-ce1` = us-central1
- `eu-we1` = europe-west1

## Terraform Implementation

```hcl
locals {
  environment = "prod"
  project_name = "app-web"

  project_id = "prj-${local.environment}-${local.project_name}"
  bucket_name = "bkt-${local.project_id}-data"
  wif_pool_id = "${local.environment}-gh-pool"
}
```

## Validation Rules
- Lowercase only
- Hyphens for separators
- No underscores
- Descriptive but concise
- Include environment indicators

See [full documentation](./NAMING-CONVENTION.md) for complete resource types.