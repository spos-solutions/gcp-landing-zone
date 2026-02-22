# Cost Breakdown

## TL;DR

**Minimum**: $0-10/month (serverless only)  
**Typical**: $80-90/month (with VMs needing NAT)

## What's FREE ✅

- ✅ **VPCs**: $0 (unlimited)
- ✅ **Subnets**: $0 (unlimited)
- ✅ **Firewall Rules**: $0 (unlimited)
- ✅ **IAM Policies**: $0
- ✅ **Folders & Organization**: $0
- ✅ **Cloud Logging**: First 50GB/month free
- ✅ **Cloud Monitoring**: Basic metrics free
- ✅ **KMS Keys**: First 20,000 operations/month free
- ✅ **GitHub Actions**: 2,000 minutes/month free (private repos)

## What Costs Money 💰

### Landing Zone Infrastructure

| Component | Cost | Notes |
|-----------|------|-------|
| **Cloud NAT** | ~$32/month per gateway | Only if you use VMs |
| **NAT Gateway** | ~$32/month per gateway | 2 gateways = $64/month |
| **Cloud Logging** | $0.50/GB after 50GB | Keep 30-day retention |
| **Cloud Storage (state)** | <$1/month | Terraform state files |
| **KMS Encryption** | ~$1-2/month | For encrypted resources |

### Per Environment

**Development (with NAT)**:
- Base VPC: $0
- Restricted VPC: $0
- Cloud NAT: $32/month
- **Total: ~$32/month**

**Production (with NAT)**:
- Base VPC: $0
- Restricted VPC: $0
- Cloud NAT: $32/month
- **Total: ~$32/month**

**NonProduction (optional, with NAT)**:
- Base VPC: $0
- Restricted VPC: $0
- Cloud NAT: $32/month
- **Total: ~$32/month**

## Scenario-Based Costs

### Scenario 1: Serverless Only (Recommended for Startups)

**What you use**:
- Cloud Run (backend APIs)
- Cloud Functions (background jobs)
- Cloud SQL or Firestore (database)
- Cloud Storage (files)

**Landing zone cost**:
- VPCs: $0
- NAT: $0 (not needed)
- Logging: $0 (within 50GB free tier)
- State storage: <$1/month
- **Total: ~$0-5/month**

**Application costs**: Pay per request/usage

---

### Scenario 2: VMs Without Internet Access

**What you use**:
- Compute Engine VMs
- Private access to Google APIs only
- No outbound internet needed

**Landing zone cost**:
- VPCs: $0
- NAT: $0 (not needed)
- Logging: $0-10/month
- **Total: ~$5-15/month**

**Application costs**: VM charges (~$25-200/month per VM)

---

### Scenario 3: VMs With Internet Access

**What you use**:
- Compute Engine VMs
- Need outbound internet (apt-get, pip install, etc.)
- Cloud NAT required

**Landing zone cost** (dev + prod):
- VPCs: $0
- 2x Cloud NAT: $64/month
- Logging: $10-20/month
- **Total: ~$75-85/month**

**Application costs**: VM charges + egress

---

### Scenario 4: Full Enterprise Setup

**What you use**:
- All three environments (dev + nonprod + prod)
- VMs in each environment
- Cloud NAT in each environment

**Landing zone cost**:
- VPCs: $0
- 3x Cloud NAT: $96/month
- Logging: $20-30/month
- Monitoring dashboards: $5-10/month
- **Total: ~$120-140/month**

---

## Cost Optimization Tips

### 1. Skip Cloud NAT for Serverless

```bash
# In 3-networks/envs/development/terraform.tfvars
enable_nat = false
```

**Savings**: $32/month per environment

**Works for**:
- Cloud Run
- Cloud Functions
- App Engine
- Cloud SQL (private IP)

---

### 2. Start with Only Dev + Prod

```bash
cd 2-environments
echo "envs/nonproduction/" >> .gitignore

cd ../3-networks
echo "envs/nonproduction/" >> .gitignore

cd ../4-projects
echo "business_unit_1/nonproduction/" >> .gitignore
```

**Savings**: $32-40/month

---

### 3. Reduce Logging Retention

```hcl
# In 1-org/envs/shared/terraform.tfvars
logging_retention_days = 30  # Instead of 365
```

**Savings**: $20-50/month depending on log volume

---

### 4. Use Smaller VM Types

```hcl
machine_type = "e2-micro"      # $6/month
# Instead of:
machine_type = "n2-standard-2" # $70/month
```

---

### 5. Use Preemptible/Spot VMs

```hcl
preemptible = true  # 60-91% discount
```

---

### 6. Enable Cloud Storage Lifecycle Policies

```hcl
lifecycle_rule {
  condition {
    age = 90
  }
  action {
    type = "Delete"
  }
}
```

---

## Monthly Cost Calculator

```
Base Landing Zone: $5/month

+ Cloud NAT Dev:     $32/month (if VMs)
+ Cloud NAT Prod:    $32/month (if VMs)
+ Cloud NAT NonProd: $32/month (if VMs, optional)
+ Logging (>50GB):   $0.50/GB
+ Monitoring:        $5-10/month (optional dashboards)

= Total Infrastructure Cost
```

**Examples**:
- Serverless only: **$5/month**
- Dev + Prod VMs: **$70-80/month**
- Full enterprise: **$120-140/month**

---

## Viewing Your Actual Costs

```bash
# View billing in console
gcloud billing accounts list
gcloud alpha billing budgets list --billing-account=${BILLING_ACCOUNT}

# Export billing to BigQuery for detailed analysis
# Setup in: https://console.cloud.google.com/billing/export
```

---

## Setting Up Budget Alerts

```hcl
# In 0-bootstrap (optional)
resource "google_billing_budget" "landing_zone" {
  billing_account = var.billing_account
  display_name    = "Landing Zone Budget"
  
  amount {
    specified_amount {
      units = "100"  # $100/month
    }
  }
  
  threshold_rules {
    threshold_percent = 0.5   # Alert at 50%
  }
  threshold_rules {
    threshold_percent = 0.9   # Alert at 90%
  }
  threshold_rules {
    threshold_percent = 1.0   # Alert at 100%
  }
}
```

---

## Cost Breakdown by Stage

| Stage | What It Creates | Monthly Cost |
|-------|-----------------|--------------|
| 0-bootstrap | State bucket, CI/CD project | <$1 |
| 1-org | Folders, IAM, policies | $0 |
| 2-environments | Folder structure | $0 |
| 3-networks | VPCs, subnets, NAT | $0-96 (NAT) |
| 4-projects | Empty projects | $0 |

**Your applications** (Cloud Run, VMs, databases) cost extra.

---

## Hidden Costs to Watch

- **Egress**: >1GB/month from VMs is charged
- **Load Balancers**: $18/month per LB
- **VPN Tunnels**: $36/month per tunnel (if you add later)
- **Interconnect**: $100+/month (not in this setup)
- **Secret Manager**: $0.06 per 10,000 operations after free tier

---

## Free Tier Resources

Always free:
- 1x f1-micro VM instance/month (US regions)
- 5GB Cloud Storage
- 30GB HDD storage
- 1GB egress to North America/month

---

## Questions?

Check actual pricing: https://cloud.google.com/pricing/calculator
