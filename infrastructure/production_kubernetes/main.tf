data "terraform_remote_state" "production_gcp" {
  backend = "remote"

  config = {
    hostname     = "app.terraform.io"
    organization = "neon-law"
    workspaces = {
      name = "production-gcp"
    }
  }
}

provider "kubernetes" {
  load_config_file = false

  host     = data.terraform_remote_state.production_gcp.outputs.gke_host
  username = data.terraform_remote_state.production_gcp.outputs.gke_username
  password = data.terraform_remote_state.production_gcp.outputs.gke_password

  client_certificate     = base64decode(data.terraform_remote_state.production_gcp.outputs.gke_client_certificate)
  client_key             = base64decode(data.terraform_remote_state.production_gcp.outputs.gke_client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.production_gcp.outputs.gke_cluster_ca_certificate)
}

module "sql_proxy_kubernetes_secret" {
  source       = "../modules/kubernetes_secret"
  secret_name  = "sql-proxy-service-account-token"
  secret_value = var.sql_proxy_gcp_credentials
}

module "third_party_saas_kubernetes_secret" {
  source              = "../modules/third_party_saas_kubernetes_secret"
  secret_name         = "third-party-saas"
  auth0_client_id     = var.auth0_client_id
  auth0_client_secret = var.auth0_client_secret
  auth0_tenant        = "auth.neonlaw.com"
}

module "logic_kubernetes_secret" {
  source       = "../modules/kubernetes_secret"
  secret_name  = "logic"
  secret_value = var.logic_gcp_credentials
}

module "api_deployment" {
  source                       = "../modules/api_deployment"
  app_name                     = "api"
  image_url                    = "${data.terraform_remote_state.production_gcp.outputs.container_registry}/api:latest"
  database_name                = "neon-law"
  show_graphiql                = "false"
  project_id                   = data.terraform_remote_state.production_gcp.outputs.project_id
  region                       = data.terraform_remote_state.production_gcp.outputs.region
  sql_proxy_secret_name        = module.sql_proxy_kubernetes_secret.name
  third_party_saas_secret_name = module.third_party_saas_kubernetes_secret.name
  logic_secret_name            = module.logic_kubernetes_secret.name
  master_database_password     = var.master_database_password
}

module "interface_deployment" {
  source    = "../modules/interface_deployment"
  app_name  = "interface"
  image_url = "${data.terraform_remote_state.production_gcp.outputs.container_registry}/interface:latest"
}

module "law-job-resources_deployment" {
  source    = "../modules/interface_deployment"
  app_name  = "law-job-resources"
  image_url = "${data.terraform_remote_state.production_gcp.outputs.container_registry}/law-job-resources:latest"
}

module "justice_for_rickie_slaughter_deployment" {
  source    = "../modules/interface_deployment"
  app_name  = "justice-for-rickie-slaughter"
  image_url = "${data.terraform_remote_state.production_gcp.outputs.container_registry}/justice-for-rickie-slaughter:latest"
}

module "delete_your_data_deployment" {
  source    = "../modules/interface_deployment"
  app_name  = "delete-your-data"
  image_url = "${data.terraform_remote_state.production_gcp.outputs.container_registry}/delete-your-data:latest"
}

module "ingress" {
  source = "../modules/production_ingress"
  api_service_name = "api"

  neon_law_interface_service_name = "interface"
  neon_law_host = "www.neonlaw.com"

  law_job_resources_service_name = "law-job-resources"
  law_job_resources_host = "www.lawjobresources.com"

  delete_your_data_service_name = "delete-your-data"
  delete_your_data_host = "www.deleteyourdata.com"

  justice_for_rickie_slaughter_service_name = "justice-for-rickie-slaughter"
  justice_for_rickie_slaughter_host = "www.justiceforrickieslaughter.com"
}
