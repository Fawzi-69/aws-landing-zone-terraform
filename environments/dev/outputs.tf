output "vpc_id" {
  description = "Id of the environment VPC."
  value       = module.vpc.vpc_id
}

output "private_app_subnet_ids" {
  description = "Application-tier subnet ids."
  value       = module.vpc.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  description = "Data-tier subnet ids."
  value       = module.vpc.private_data_subnet_ids
}

output "finops_sns_topic_arn" {
  description = "ARN of the environment cost-alert topic."
  value       = module.finops.sns_topic_arn
}
