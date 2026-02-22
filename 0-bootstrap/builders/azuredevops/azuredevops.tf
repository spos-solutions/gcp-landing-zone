locals {
  app_id = var.azure_devops_config.app_id
  issuer_uri = var.azure_devops_config.issuer_uri
  allowed_audiences = var.azure_devops_config.allowed_audiences

  repo_config = {
    "bootstrap" = var.azure_devops_config.bootstrap,
    "org"       = var.azure_devops_config.org,
    "env"       = var.azure_devops_config.env,
    "net"       = var.azure_devops_config.net,
    "proj"      = var.azure_devops_config.proj,
  }

  sa_mapping = {
    for k, v in local.repo_config : k => {
      sa_name   = google_service_account.terraform-env-sa[k].name
      sa_email = google_service_account.terraform-env-sa[k].email
      repo_name = local.repo_config[k]
      attribute = "subject/${local.app_id}"
    }
  }
}

# get the project for cicd
data "google_project" "base_cicd" {
  project_id = module.base_cicd.project_id
}


variable "attribute_mapping" {
  type        = map(any)
  description = <<-EOF
  Workload Identity Pool Provider attribute mapping
  For more info please see:
  https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider
  EOF
  default = {
    # Principal IAM
    "google.subject" = "assertion.sub"
  }
}

resource "google_iam_workload_identity_pool" "main" {
  project                   = data.google_project.base_cicd.project_id
  workload_identity_pool_id = "foundation-pool"
  display_name              = "Foundation Pool"
  description               = null
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "main" {
  project                            = data.google_project.base_cicd.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.main.workload_identity_pool_id
  workload_identity_pool_provider_id = "foundation-provider"
  display_name                       = "Foundation Provider"
  description                        = null
  attribute_condition                = null
  attribute_mapping                  = var.attribute_mapping
  oidc {
    allowed_audiences = local.allowed_audiences
    issuer_uri        = local.issuer_uri
  }
}

resource "google_service_account_iam_member" "wif-ado-wif" {
  for_each           = local.sa_mapping
  service_account_id = each.value.sa_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.main.name}/${each.value.attribute}"
}

output "workload_identity_pool_provider_name" {
  description = "Workload Identity Pool Provider URI for cred generation"
  value = "projects/${data.google_project.base_cicd.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool_provider.main.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.main.workload_identity_pool_provider_id}"
}

output "service_account_list" {

    # 
    # Produces the following string to be used in Azure Devops pipeline library
    # 
    # {"gcp-bootstrap":"sa-terraform-bootstrap@prj-b-seed-nnnn.iam.gserviceaccount.com","gcp-org":"sa-terraform-org@prj-b-seed-nnnn.iam.gserviceaccount.com"}
    # 

    description = "Service Account list for Workload Identity Pool Provider"

    value = "{${join(",\n", [for k, v in local.sa_mapping : "\"${v.repo_name}\":\"${v.sa_email}\""])}}"


}