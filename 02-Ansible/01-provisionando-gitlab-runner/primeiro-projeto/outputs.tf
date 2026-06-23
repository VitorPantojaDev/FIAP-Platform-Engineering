output "api_base_url" {
  description = "URL base da API da frota. Teste com: curl <url>/scooters"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "scooters_table" {
  description = "Nome da tabela DynamoDB de status das scooters."
  value       = aws_dynamodb_table.scooters.name
}
