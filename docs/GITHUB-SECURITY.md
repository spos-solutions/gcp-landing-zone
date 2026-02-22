# GitHub Repository Security Configuration

This guide covers securing your GitHub repositories for the GCP Landing Zone Terraform deployment.

## Prerequisites

- GitHub account with admin access to the organization/repositories
- GitHub CLI (`gh`) installed: `brew install gh`
- Fine-grained Personal Access Token (PAT) with appropriate permissions

## Required GitHub Repository

Create a single **private** repository:

- `gcp-landing-zone` (or your preferred name)
  - Contains all stages: 0-bootstrap, 1-org, 2-environments, 3-networks, 4-projects
  - All workflows in `.github/workflows/`
  - Monorepo structure simplifies management

## Branch Structure

The repository uses:
- `main` - Protected production branch (auto-deploys on merge)
- `plan` or `dev` - Development branches (plan-only, no apply)

## Security Configuration

### 1. Branch Protection Rules for `main` Branch

Configure the following protections on the `main` branch:

#### Required Settings:
- ✅ **Require a pull request before merging**
  - Require approvals: 1
  - Dismiss stale pull request approvals when new commits are pushed
  - Require review from Code Owners (optional but recommended)
- ✅ **Require status checks to pass before merging**
  - Require branches to be up to date before merging
  - Required status checks:
    - `terraform-plan` (from your workflows)
    - `opa-validate` (policy validation)
- ✅ **Require conversation resolution before merging**
- ✅ **Require linear history** (optional, keeps history clean)
- ✅ **Do not allow bypassing the above settings**
- ✅ **Restrict who can push to matching branches**
  - Only allow GitHub Actions service account
  - No direct pushes, all changes via PR
- ✅ **Block force pushes**
- ✅ **Allow deletions** - ❌ Disabled

#### Recommended Settings:
- ✅ **Require deployments to succeed before merging** (if using environments)
- ✅ **Require signed commits** (for enhanced security)
- ✅ **Lock branch** (for compliance, prevents all changes)

#### Additional Protection:
- `main` is the production branch - treat it as critical
- All changes must go through PRs from feature/plan branches
- Direct pushes to main are blocked

### 2. Repository Security Settings

Navigate to: Repository → Settings → Security

#### Code Scanning:
- ✅ Enable Dependabot alerts
- ✅ Enable Dependabot security updates
- ✅ Enable CodeQL analysis (optional for Terraform)

#### Secrets Scanning:
- ✅ Enable secret scanning
- ✅ Enable push protection (prevents accidental secret commits)

#### Access Control:
- Set repository visibility to **Private**
- Limit access to required teams/users only
- Use teams for permission management

### 3. Fine-Grained Personal Access Token

Create a token at: https://github.com/settings/tokens?type=beta

#### Required Permissions:

**Repository Access:**
- Select: "Only select repositories"
- Include: Your landing zone repository (e.g., `gcp-landing-zone`)

**Repository Permissions:**
- Actions: **Read and Write**
- Administration: **Read** (for branch protection)
- Contents: **Read and Write**
- Metadata: **Read-only** (automatically included)
- Secrets: **Read and Write**
- Variables: **Read and Write**
- Workflows: **Read and Write**

**Organization Permissions (if using organization):**
- Members: **Read** (optional, for team management)

#### Token Security:
- Set expiration: 90 days (rotate regularly)
- Document token usage
- Store securely (never commit to repositories)
- Rotate immediately if compromised

## Automated Setup Commands

### Using GitHub CLI

Authenticate:
```bash
gh auth login
```

### Set Branch Protection:

```bash
REPO="YOUR-GITHUB-OWNER/gcp-landing-zone"

# Create production branch
gh api "repos/${REPO}/git/refs" \
  -f ref="refs/heads/production" \
  -f sha=$(gh api "repos/${REPO}/git/refs/heads/main" -q .object.sha)

# Enable branch protection for production
gh api "repos/${REPO}/branches/production/protection" -X PUT \
  -f required_status_checks[strict]=true \
  -f required_status_checks[contexts][]=terraform-plan \
  -f required_status_checks[contexts][]=opa-validate \
  -f enforce_admins=true \
  -f required_pull_request_reviews[dismiss_stale_reviews]=true \
  -f required_pull_request_reviews[require_code_owner_reviews]=false \
  -f required_pull_request_reviews[required_approving_review_count]=1 \
  -f required_conversation_resolution=true \
  -f required_linear_history=false \
  -f allow_force_pushes=false \
  -f allow_deletions=false \
  -f block_creations=false

echo "✅ Branch protection configured for ${REPO}"
```

### Automated Setup Script

See [setup-github-security.sh](../scripts/setup-github-security.sh) for automated configuration.

## Repository Environments (Optional but Recommended)

GitHub Environments provide additional deployment controls.

### Create Environments:

Create the following environments in your repository:
- `development` - Auto-deployed on plan branch
- `production` - Manual approval required

#### Environment Protection Rules:

**Production Environment:**
- Required reviewers: 1-2 designated approvers
- Wait timer: 0 minutes (or add delay for change windows)
- Deployment branches: Only `production` branch

**Development Environment:**
- No required reviewers
- Deployment branches: Any branch except `production`

### Configure in GitHub:
Repository → Settings → Environments → New environment

Then update your workflows to use environments:
```yaml
jobs:
  terraform-apply:
    runs-on: ubuntu-latest
    environment: production  # Triggers approval workflow
    steps:
      # ... deployment steps
```

## Verification Checklist

After configuration, verify:

- [ ] Repository is created and set to Private
- [ ] `main` branch exists and is default
- [ ] Branch protection rules are active on `main` branch
- [ ] Required status checks include `terraform-plan` and `opa-validate`
- [ ] Force pushes are blocked
- [ ] At least 1 approval required for PRs
- [ ] Dependabot alerts are enabled
- [ ] Secret scanning is enabled with push protection
- [ ] Fine-grained PAT is created with correct permissions
- [ ] PAT is stored as environment variable `TF_VAR_gh_token`
- [ ] Team access is configured appropriately
- [ ] All GitHub Actions workflows are present in `.github/workflows/`

## Security Best Practices

1. **Never commit secrets to repositories**
   - Use GitHub Secrets for sensitive values
   - Enable secret scanning push protection

2. **Regular token rotation**
   - Set calendar reminders to rotate PATs
   - Use short expiration periods (90 days max)

3. **Audit access regularly**
   - Review repository access quarterly
   - Remove users who no longer need access

4. **Monitor security alerts**
   - Enable email notifications for Dependabot
   - Review and remediate vulnerabilities promptly

5. **Enforce MFA**
   - Require 2FA for all organization members
   - Use hardware security keys for admin accounts

6. **Review workflow runs**
   - Monitor Actions usage for anomalies
   - Review failed workflow runs

7. **Use CODEOWNERS file**
   - Define code owners for critical files
   - Require owner approval for sensitive changes

## Example CODEOWNERS File

Create `.github/CODEOWNERS` in each repository:

```
# Terraform infrastructure owners
*.tf @your-org/infrastructure-team
*.tfvars @your-org/infrastructure-team

# Workflow security team approval required
.github/workflows/* @your-org/security-team

# Policy library requires security review
policy-library/* @your-org/security-team
```

## Troubleshooting

### Issue: Branch protection not working
- Verify you have admin rights to the repository
- Check that status check names match workflow job names exactly
- Ensure workflows have run at least once to register status checks

### Issue: Actions failing with permissions error
- Verify PAT has not expired
- Check PAT has correct repository permissions
- Ensure repository secrets are correctly configured

### Issue: Cannot merge to production
- Verify required status checks have passed
- Check that PR has required approvals
- Ensure all conversations are resolved

## Next Steps

After securing your repositories, proceed to:
1. [Bootstrap WIF Setup](./BOOTSTRAP-WIF-SETUP.md)
2. Configure Terraform backend
3. Deploy bootstrap infrastructure

## References

- [GitHub Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Fine-grained PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning)
