# Tabela que guarda o status de cada scooter da frota. On-demand (PAY_PER_REQUEST):
# sem capacidade provisionada, custo proporcional ao uso e dentro do free-tier.
resource "aws_dynamodb_table" "scooters" {
  name         = "${var.project}-scooters"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "scooter_id"

  attribute {
    name = "scooter_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}
