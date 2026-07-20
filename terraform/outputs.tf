output "rds_auth_endpoint" {
  value       = aws_db_instance.postgres["auth"].endpoint
  description = "Endpoint do banco de dados PostgreSQL do Auth Service"
}

output "rds_flags_endpoint" {
  value       = aws_db_instance.postgres["flags"].endpoint
  description = "Endpoint do banco de dados PostgreSQL do Flag Service"
}

output "rds_targeting_endpoint" {
  value       = aws_db_instance.postgres["targeting"].endpoint
  description = "Endpoint do banco de dados PostgreSQL do Targeting Service"
}

output "redis_primary_endpoint" {
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
  description = "Endereço primário do Cluster Redis ElastiCache"
}

output "sqs_queue_url" {
  value       = aws_sqs_queue.events.url
  description = "URL da fila SQS para comunicação dos serviços"
}
