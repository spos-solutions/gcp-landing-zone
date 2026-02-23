/**
 * Copyright 2021 Google LLC
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

/******************************************
  SCC Notification
*****************************************/

locals {
  scc_notification_suffix = var.enable_scc_notification && var.create_unique_scc_notification ? "-${random_string.scc_notification_key_suffix[0].result}" : ""
  scc_notification_name   = "${var.scc_notification_name}${local.scc_notification_suffix}"
}
resource "random_string" "scc_notification_key_suffix" {
  count   = var.enable_scc_notification ? 1 : 0
  length  = 8
  special = false
  upper   = false
}
resource "google_pubsub_topic" "scc_notification_topic" {
  count   = var.enable_scc_notification ? 1 : 0
  name    = "top-scc-notification"
  project = module.scc_notifications.project_id

  message_storage_policy {
    allowed_persistence_regions = [
      "northamerica-northeast1",
      "northamerica-northeast2",
    ]
    # enforce_in_transit = true
  }

}

resource "google_pubsub_subscription" "scc_notification_subscription" {
  count   = var.enable_scc_notification ? 1 : 0
  name    = "sub-scc-notification"
  topic   = google_pubsub_topic.scc_notification_topic[0].name
  project = module.scc_notifications.project_id
}

resource "google_scc_notification_config" "scc_notification_config" {
  count        = var.enable_scc_notification ? 1 : 0
  config_id    = local.scc_notification_name
  organization = local.org_id
  description  = "SCC Notification for all active findings"
  pubsub_topic = google_pubsub_topic.scc_notification_topic[0].id

  streaming_config {
    filter = var.scc_notification_filter
  }
}
