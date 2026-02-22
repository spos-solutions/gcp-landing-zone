# GCP Resource Naming Convention

## Overview
This document defines the naming convention for GCP resources in the landing zone. The convention ensures consistency, readability, and compliance with GCP resource name limits.

## General Rules
- **Case**: Lowercase only (except where GCP requires uppercase)
- **Separators**: Use hyphens (-) for readability, avoid underscores (_)
- **Abbreviations**: Use consistent short forms
- **Hierarchy**: Include environment/stage indicators
- **Uniqueness**: Ensure global uniqueness where required

## Resource-Specific Conventions

### Projects
**Format**: `prj-{environment}-{purpose}-{identifier}`
- `prj`: Fixed prefix
- `environment`: b (bootstrap), d (development), s (staging), p (production)
- `purpose`: seed, cicd, app, data, etc.
- `identifier`: Short descriptive name

**Examples**:
- `prj-b-seed-spos` - Bootstrap seed project
- `prj-p-app-web` - Production web application
- `prj-d-data-lake` - Development data lake

### Folders
**Format**: `fldr-{environment}-{purpose}`
- `fldr`: Fixed prefix
- `environment`: b, d, s, p
- `purpose`: bootstrap, development, production, etc.

**Examples**:
- `fldr-bootstrap` - Bootstrap folder
- `fldr-development` - Development folder

### Buckets
**Format**: `bkt-{project_prefix}-{purpose}-{suffix}`
- `bkt`: Fixed prefix
- `project_prefix`: From project naming
- `purpose`: tfstate, logs, data, etc.
- `suffix`: Optional random suffix for uniqueness

**Examples**:
- `bkt-prj-b-seed-tfstate` - Bootstrap state bucket
- `bkt-prj-p-app-logs` - Production app logs

### Service Accounts
**Format**: `sa-{purpose}-{environment}@{project}.iam.gserviceaccount.com`
- `sa`: Fixed prefix
- `purpose`: terraform, app, compute, etc.
- `environment`: bootstrap, dev, prod, etc.

**Examples**:
- `sa-terraform-bootstrap@prj-b-seed-spos.iam.gserviceaccount.com`
- `sa-app-backend@prj-p-app-web.iam.gserviceaccount.com`

### Workload Identity Pools
**Format**: `{environment}-{purpose}-pool`
- `environment`: bootstrap, development, production
- `purpose`: gh (GitHub), k8s (Kubernetes), etc.

**Examples**:
- `bootstrap-gh-pool` - Bootstrap GitHub pool
- `production-k8s-pool` - Production Kubernetes pool

### Workload Identity Providers
**Format**: `{environment}-{source}-provider`
- `environment`: bootstrap, development, production
- `source`: gh (GitHub), aws, azure, etc.

**Examples**:
- `bootstrap-gh-provider` - Bootstrap GitHub provider
- `production-aws-provider` - Production AWS provider

### Cloud Storage Buckets (Data)
**Format**: `{org}-{environment}-{purpose}-{region}`
- `org`: Organization short name
- `environment`: dev, staging, prod
- `purpose`: data, logs, backups
- `region`: na-ne1, eu-we1, etc.

**Examples**:
- `spos-prod-data-na-ne1` - Production data in North America Northeast
- `spos-dev-logs-eu-we1` - Development logs in Europe West

### BigQuery Datasets
**Format**: `{environment}_{purpose}_{team}`
- `environment`: dev, staging, prod
- `purpose`: analytics, audit, reporting
- `team`: Short team name

**Examples**:
- `prod_analytics_marketing`
- `dev_audit_security`

### Cloud SQL Instances
**Format**: `{environment}-{purpose}-{identifier}`
- `environment`: dev, staging, prod
- `purpose`: app, data, cache
- `identifier`: Short identifier

**Examples**:
- `prod-app-main` - Production main app database
- `dev-cache-redis` - Development Redis cache

### Compute Engine VMs
**Format**: `{environment}-{purpose}-{number}`
- `environment`: dev, staging, prod
- `purpose`: web, api, worker
- `number`: 001, 002, etc.

**Examples**:
- `prod-web-001` - Production web server 1
- `dev-api-002` - Development API server 2

### Kubernetes Clusters
**Format**: `gke-{environment}-{region}-{purpose}`
- `gke`: Fixed prefix
- `environment`: dev, staging, prod
- `region`: na-ne1, eu-we1
- `purpose`: app, data, system

**Examples**:
- `gke-prod-na-ne1-app` - Production app cluster
- `gke-dev-eu-we1-system` - Development system cluster

### Cloud Functions
**Format**: `{environment}-{purpose}-{action}`
- `environment`: dev, staging, prod
- `purpose`: api, processor, notifier
- `action`: Short action name

**Examples**:
- `prod-api-webhook` - Production webhook API
- `dev-processor-image` - Development image processor

### Pub/Sub Topics
**Format**: `{environment}.{purpose}.{event}`
- `environment`: dev, staging, prod
- `purpose`: orders, users, notifications
- `event`: created, updated, deleted

**Examples**:
- `prod.orders.created` - Production order created events
- `dev.users.updated` - Development user updated events

### VPC Networks
**Format**: `vpc-{environment}-{purpose}`
- `vpc`: Fixed prefix
- `environment`: dev, staging, prod
- `purpose`: shared, app, data

**Examples**:
- `vpc-prod-shared` - Production shared VPC
- `vpc-dev-app` - Development app VPC

### Subnets
**Format**: `subnet-{environment}-{region}-{purpose}`
- `subnet`: Fixed prefix
- `region`: na-ne1, eu-we1
- `purpose`: app, data, mgmt

**Examples**:
- `subnet-prod-na-ne1-app` - Production app subnet
- `subnet-dev-eu-we1-data` - Development data subnet

## Environment Codes
- `b`: Bootstrap
- `d`: Development
- `s`: Staging
- `p`: Production
- `q`: QA
- `u`: UAT

## Region Codes
- `na-ne1`: northamerica-northeast1
- `na-ce1`: northamerica-central1
- `us-ce1`: us-central1
- `us-ea1`: us-east1
- `us-we1`: us-west1
- `eu-we1`: europe-west1
- `eu-we2`: europe-west2
- `eu-ce1`: europe-central1

## Implementation Notes
1. **Automation**: Use Terraform locals and variables to enforce naming
2. **Validation**: Implement naming validation in CI/CD pipelines
3. **Documentation**: Update this document as new resource types are added
4. **Exceptions**: Document any exceptions with justification
5. **Migration**: Plan for renaming existing resources if needed

## Example Terraform Implementation

```hcl
locals {
  environment = "prod"
  region_code = "na-ne1"
  project_name = "app-web"

  # Project
  project_id = "prj-${local.environment}-${local.project_name}"

  # Service Account
  sa_name = "sa-app-backend"

  # Bucket
  bucket_name = "bkt-${local.project_id}-data"

  # WIF Pool
  wif_pool_id = "${local.environment}-gh-pool"
}
```</content>
<parameter name="filePath">/Users/nour/git/gcp-landing-zone/docs/NAMING-CONVENTION.md