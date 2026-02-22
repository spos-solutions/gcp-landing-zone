# Consolidated Workflow Pattern

## Overview

The GitHub Actions workflows have been **consolidated** to combine plan and apply operations into single workflow files. This eliminates duplication and ensures that the exact plan being reviewed is what gets applied.

## What Changed

### Before (Separate Files)
```
.github/workflows/
├── 0-bootstrap-apply.yaml
├── 0-bootstrap-plan.yaml
├── 1-org-apply.yaml
├── 1-org-plan.yaml
├── 2-environments-apply.yaml
├── 2-environments-plan.yaml
├── 3-networks-apply.yaml
├── 3-networks-plan.yaml
├── 4-projects-apply.yaml
└── 4-projects-plan.yaml
```

### After (Consolidated)
```
.github/workflows/
├── 0-bootstrap.yaml       ✨ Combined
├── 1-org.yaml             ✨ Combined
├── 2-environments.yaml    ✨ Combined
├── 3-networks.yaml        ✨ Combined
└── 4-projects.yaml        ✨ Combined
```

## How It Works

### Trigger Logic

Each workflow responds to **two events**:

```yaml
on:
  pull_request:
    branches:
      - production
    paths:
      - '3-networks/**'
      - 'policy-library/**'
  push:
    branches:
      - production
    paths:
      - '3-networks/**'
      - 'policy-library/**'
```

### Execution Logic

**On Pull Request** → Run PLAN only:
```yaml
- name: Terraform Plan
  run: terraform plan -input=false -out=tfplan
  
- name: OPA Policy Validation
  uses: ./.github/actions/opa-validate
  
# Apply step skipped (condition not met)
- name: Terraform Apply
  if: github.event_name == 'push' && github.ref == 'refs/heads/production'
  run: terraform apply -auto-approve -input=false tfplan
```

**On Push to Production** → Run PLAN + APPLY:
```yaml
# Same steps, but Apply runs because condition is met
```

### Key Design Decisions

#### 1. **Always Regenerate Plan Before Apply**

**Why?** 
- Infrastructure may have changed between PR creation and merge
- Ensures consistency and security
- Prevents applying stale plans

**How?**
```yaml
# Plan is generated fresh in the same job
- name: Terraform Plan
  run: terraform plan -out=tfplan

# Apply uses the just-generated plan
- name: Terraform Apply
  if: github.event_name == 'push'
  run: terraform apply tfplan
```

#### 2. **Continue on Error for PRs**

```yaml
- name: Terraform Plan
  continue-on-error: ${{ github.event_name == 'pull_request' }}
```

- PRs can show plans even if they fail (for review)
- Push to production **fails fast** if plan errors

#### 3. **Environment Protection**

```yaml
environment: ${{ github.event_name == 'push' && 'production' || null }}
```

- Only applies when pushing to production
- Allows for manual approval gates if configured
- Provides audit trail

## Workflow Execution Examples

### Example 1: Creating a PR

```bash
git checkout -b feature/add-vpc
# Make changes to 3-networks/
git commit -m "Add new VPC"
git push origin feature/add-vpc
# Create PR: feature/add-vpc → production
```

**What Happens:**
1. ✅ `3-networks.yaml` workflow triggers on `pull_request`
2. ✅ Runs: `init` → `validate` → `plan` → `OPA validation`
3. ✅ Comments plan output on PR
4. ⏭️ **Skips** `apply` step (not a push to production)

### Example 2: Merging PR

```bash
# After PR approval, merge to production
```

**What Happens:**
1. ✅ `3-networks.yaml` workflow triggers on `push` to `production`
2. ✅ Runs: `init` → `validate` → `plan` → `OPA validation`
3. ✅ **Runs** `apply` step ← Infrastructure deployed!
4. ✅ Uses GitHub environment protection if configured

### Example 3: Direct Push (Emergency)

```bash
git checkout production
# Make urgent fix
git commit -m "Emergency fix"
git push origin production
```

**What Happens:**
1. ✅ Workflow triggers on `push`
2. ✅ Plan + Apply execute immediately
3. ⚠️ No PR review (use carefully!)

## Benefits

### 1. **DRY (Don't Repeat Yourself)**
- 50% fewer workflow files
- Easier to maintain
- Consistent behavior

### 2. **Safety**
- Plan always regenerated before apply
- No stale plan files
- OPA validation runs on both PR and merge

### 3. **Visibility**
- Single workflow to check for status
- Clear separation: PR = preview, Merge = deploy
- Consistent naming

### 4. **Flexibility**
- Can still manually trigger workflows
- Environment protection available
- Easy to add approval gates

## Migration Guide

### For Existing Repos

1. **Delete old workflow files:**
   ```bash
   rm .github/workflows/*-apply.yaml
   rm .github/workflows/*-plan.yaml
   ```

2. **Keep new consolidated files:**
   ```bash
   # These are already created:
   .github/workflows/0-bootstrap.yaml
   .github/workflows/1-org.yaml
   .github/workflows/2-environments.yaml
   .github/workflows/3-networks.yaml
   .github/workflows/4-projects.yaml
   ```

3. **Test with a PR:**
   ```bash
   git checkout -b test/workflow-consolidation
   git add .github/workflows/
   git commit -m "Consolidate workflows"
   git push origin test/workflow-consolidation
   # Create PR and verify plan runs correctly
   ```

4. **Clean up branches:**
   - Old workflows will stop triggering
   - New workflows take over immediately

### Rollback Plan

If issues arise, you can temporarily:
1. Rename old files back to `.yaml` extension
2. Rename new consolidated files to `.yaml.bak`
3. This gives immediate rollback without losing work

## Advanced Patterns

### Adding Manual Approval

```yaml
jobs:
  terraform:
    environment: 
      name: production
      url: https://console.cloud.google.com
    # This will wait for approval in GitHub UI
```

### Adding Slack Notifications

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "Terraform ${{ steps.plan.outcome }}: ${{ github.ref }}"
      }
```

### Cost Estimation

```yaml
- name: Terraform Cost Estimate
  uses: terraform-cost-estimation/action@v1
  with:
    plan_file: tfplan
```

## Troubleshooting

### "Workflow not found"

**Cause:** Old workflow names referenced in branch protection rules.

**Fix:** Update branch protection rules:
```
Settings → Branches → Branch protection rules → production
Required status checks: Update to new workflow names
```

### "Apply not running on merge"

**Cause:** Condition not met.

**Check:**
1. Branch is exactly `production` (not `main` or `master`)
2. Event is `push` (not `pull_request`)
3. No syntax errors in `if` condition

**Debug:**
```yaml
- name: Debug
  run: |
    echo "Event: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "Should apply: ${{ github.event_name == 'push' && github.ref == 'refs/heads/production' }}"
```

### "Plan file not found"

**Cause:** Plan generation failed silently.

**Fix:** Check plan step logs:
```yaml
- name: Terraform Plan
  run: |
    set -x  # Enable debug
    terraform plan -out=tfplan
    ls -la tfplan  # Verify file exists
```

## Best Practices

✅ **DO:**
- Always review plan output in PR before merging
- Use branch protection to require approvals
- Monitor workflow runs in Actions tab
- Keep policy library up to date

❌ **DON'T:**
- Don't push directly to production without review
- Don't disable OPA validation (except for debugging)
- Don't skip environment protection for production
- Don't apply without reviewing plan first

## Questions?

**Why not use workflow artifacts to pass plan from PR to merge?**
- Artifact availability/expiration issues
- Security: want fresh plan for safety
- Simpler: no artifact management needed

**Why not use `workflow_dispatch` or `workflow_call`?**
- Current approach is simpler
- Fewer abstractions to understand
- Direct event-driven execution

**Can I still manually trigger workflows?**
- Yes! Use GitHub UI: Actions → Select workflow → Run workflow
- Can specify branch/inputs if needed
