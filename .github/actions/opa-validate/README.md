# OPA Policy Validation for GitHub Actions

This directory contains a reusable GitHub Actions composite action for validating Terraform plans against OPA/Rego policies.

## Overview

The OPA validation action automatically runs after each `terraform plan` step in your CI/CD pipeline to enforce compliance and security policies defined in the `policy-library` before infrastructure changes are applied.

## Features

- ✅ **Automatic validation** of Terraform plans against Rego policies
- ✅ **Fail-fast** approach - blocks PRs if policy violations are detected
- ✅ **Artifact uploads** - Terraform plan JSON saved for debugging
- ✅ **Consistent enforcement** across all stages (bootstrap, org, environments, networks, projects)

## How It Works

1. **Install OPA** - Downloads and installs the latest OPA CLI
2. **Convert Plan** - Converts Terraform binary plan to JSON format
3. **Validate** - Runs OPA evaluation against policy library
4. **Report** - Shows violations and fails if configured
5. **Archive** - Uploads plan JSON as workflow artifact

## Usage

The action is automatically integrated into all `*-plan.yaml` workflows:

```yaml
- name: OPA Policy Validation
  uses: ./.github/actions/opa-validate
  with:
    terraform-plan-file: 'tfplan'
    working-directory: '3-networks/envs/production'
    policy-library-path: 'policy-library'
    fail-on-violation: 'true'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `terraform-plan-file` | Path to terraform plan file (tfplan) | Yes | - |
| `working-directory` | Working directory containing the plan file | Yes | - |
| `policy-library-path` | Path to policy library | No | `policy-library` |
| `fail-on-violation` | Fail workflow if violations found | No | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `violations-found` | Boolean indicating if violations were detected |

## Integration Status

OPA validation is integrated into the following workflows:

- ✅ `0-bootstrap-plan.yaml` - Bootstrap validation
- ✅ `1-org-plan.yaml` - Organization policies
- ✅ `2-environments-plan.yaml` - Environment setup (dev/nonprod/prod)
- ✅ `3-networks-plan.yaml` - Network configuration (all envs)
- ✅ `4-projects-plan.yaml` - Project creation (shared/dev/nonprod/prod)

## Policy Library Structure

Your policies are located in `policy-library/`:

```
policy-library/
├── lib/                    # Reusable Rego functions
│   ├── constraints.rego
│   └── util.rego
└── policies/
    ├── constraints/        # Policy instances
    │   ├── sql_no_public_ip.yaml
    │   ├── gke_allow_only_private_cluster.yaml
    │   └── ...
    └── templates/          # Policy templates with Rego code
        ├── gcp_sql_public_ip_v1.yaml
        ├── gcp_gke_container_optimized_os.yaml
        └── ...
```

## Example Workflow

When you create a PR:

```bash
git checkout -b feature/add-network
# Make infrastructure changes
git add .
git commit -m "Add new VPC"
git push origin feature/add-network
# Create PR to production branch
```

GitHub Actions will:
1. ✅ Run `terraform init`
2. ✅ Run `terraform validate`
3. ✅ Run `terraform plan`
4. **✅ Run OPA policy validation** ← New!
5. ✅ Comment plan output on PR
6. ❌ Block merge if violations found

## Viewing Results

### In PR Comments
Plan output includes policy validation status

### In Actions Tab
- Navigate to `Actions` tab in GitHub
- Click on the workflow run
- View the "OPA Policy Validation" step for details

### Downloaded Artifacts
- Terraform plan JSON files are saved as artifacts
- Download from workflow run page
- Retention: 30 days

## Adding New Policies

1. **Add constraint template** to `policy-library/policies/templates/`:
   ```yaml
   apiVersion: templates.gatekeeper.sh/v1alpha1
   kind: ConstraintTemplate
   metadata:
     name: my-custom-policy
   spec:
     targets:
       validation.gcp.forsetisecurity.org:
         rego: |
           package templates.gcp.MyCustomPolicy
           deny[{"msg": message}] {
             # Your Rego logic here
           }
   ```

2. **Create constraint** in `policy-library/policies/constraints/`:
   ```yaml
   apiVersion: constraints.gatekeeper.sh/v1alpha1
   kind: MyCustomPolicy
   metadata:
     name: enforce-my-policy
   spec:
     severity: high
     match:
       target: ["organizations/**"]
   ```

3. **Commit and push** - validation runs automatically

## Troubleshooting

### Validation Fails with "No rego files found"
- Check that `policy-library/` exists in repo root
- Ensure `.rego` files are in `policy-library/lib/`

### False Positives
- Review policy logic in template files
- Adjust policy parameters in constraint files
- Set `fail-on-violation: 'false'` temporarily to debug

### Need to Skip Validation
Temporarily disable by commenting out the validation step in workflow file (not recommended for production).

## Comparison with gcloud terraform vet

| Feature | OPA (This Setup) | gcloud terraform vet |
|---------|-----------------|---------------------|
| Installation | Downloaded in CI | Requires gcloud SDK |
| Speed | Fast | Moderate |
| Cloud dependency | None | Requires GCP project |
| Customization | Full control | Limited |
| Integration | Native to CI | External tool |

## Resources

- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Language](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [Google Policy Library](https://github.com/GoogleCloudPlatform/policy-library)
- [Terraform + OPA Guide](https://www.openpolicyagent.org/docs/latest/terraform/)

## Support

For issues with OPA validation:
1. Check workflow logs in GitHub Actions
2. Review policy library documentation
3. Test policies locally with `opa test`
