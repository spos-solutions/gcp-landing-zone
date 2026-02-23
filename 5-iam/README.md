# 5-iam

This folder manages Organization-level IAM, custom roles, and service accounts used across projects.

## Purpose
- Define custom IAM roles for the organization.
- Manage organization-level IAM bindings (e.g., granting roles to groups).
- Create and manage shared service accounts if needed.

## Usage
1. Configure `backend.tf` with your state bucket.
2. Define IAM resources in `main.tf`.
3. Run `terraform init` and `terraform apply`.
