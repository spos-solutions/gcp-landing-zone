/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  iam_config = yamldecode(file("${path.module}/iam_config.yaml"))
  
  # Flatten standard org roles
  org_roles_flat = flatten([
    for role_entry in try(local.iam_config.org_roles, []) : [
      for member in role_entry.members : {
        role   = role_entry.role
        member = member
        key    = "${role_entry.role}--${member}"
      }
    ]
  ])

  # Flatten custom role assignments (if members are defined inline)
  custom_roles_flat = flatten([
    for role in try(local.iam_config.custom_roles, []) : [
      for member in try(role.members, []) : {
        role   = "organizations/${var.org_id}/roles/${role.id}"
        member = member
        key    = "organizations/${var.org_id}/roles/${role.id}--${member}"
      }
    ]
  ])

  # Combine all IAM bindings
  all_iam_bindings = concat(local.org_roles_flat, local.custom_roles_flat)
}

# Organization IAM Bindings
resource "google_organization_iam_member" "org_iam" {
  for_each = {
    for entry in local.all_iam_bindings : entry.key => entry
  }

  org_id = var.org_id
  role   = each.value.role
  member = each.value.member
}

# Custom Roles
resource "google_organization_iam_custom_role" "custom_roles" {
  for_each = {
    for role in try(local.iam_config.custom_roles, []) : role.id => role
  }

  role_id     = each.value.id
  org_id      = var.org_id
  title       = each.value.title
  description = try(each.value.description, "")
  permissions = each.value.permissions
}
