#!/bin/bash
terraform init
FILES=".terraform/modules/env.env_secrets/modules/shared_vpc_access/main.tf .terraform/modules/env.env_kms/modules/shared_vpc_access/main.tf .terraform/modules/env.monitoring_project/modules/shared_vpc_access/main.tf"
sed -i "" "s/count    = local.gke_shared_vpc_enabled && var.enable_shared_vpc_service_project && var.grant_network_role ? length(local.subnetwork_api) : 0/count = 0/g" $FILES
sed -i "" "s/count   = local.composer_shared_vpc_enabled && var.enable_shared_vpc_service_project && var.grant_network_role ? 1 : 0/count = 0/g" $FILES
sed -i "" "s/count   = local.gke_shared_vpc_enabled && var.enable_shared_vpc_service_project && var.grant_network_role ? 1 : 0/count = 0/g" $FILES
sed -i "" "s/count   = local.gke_shared_vpc_enabled && var.enable_shared_vpc_service_project && var.grant_services_security_admin_role ? 1 : 0/count = 0/g" $FILES
sed -i "" "s/count   = local.datastream_shared_vpc_enabled && var.enable_shared_vpc_service_project && var.grant_services_network_admin_role ? 1 : 0/count = 0/g" $FILES
terraform apply -auto-approve
