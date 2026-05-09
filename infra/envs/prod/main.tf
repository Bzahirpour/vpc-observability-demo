locals {
  app_log_group_name = "/${var.project_name}/${var.environment}/app"
}

module "networking" {
  source       = "../../modules/networking"
  project_name = var.project_name
  environment  = var.environment
}

module "compute" {
  source              = "../../modules/compute"
  project_name        = var.project_name
  environment         = var.environment
  subnet_id           = module.networking.public_subnet_id
  security_group_a_id = module.networking.security_group_a_id
  security_group_b_id = module.networking.security_group_b_id
  app_log_group_name  = local.app_log_group_name
}

module "observability" {
  source                   = "../../modules/observability"
  project_name             = var.project_name
  environment              = var.environment
  instance_a_id            = module.compute.instance_a_id
  alarm_email              = var.alarm_email
  app_log_group_name       = local.app_log_group_name
  flow_logs_log_group_name = module.networking.flow_logs_log_group_name
}
