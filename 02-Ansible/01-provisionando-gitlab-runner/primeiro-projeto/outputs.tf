output "api_base_url" {
  description = "URL base da API da frota. Teste com: curl <url>/scooters"
  # trimsuffix remove a barra final do invoke_url (.../), senao "$API_URL/scooters"
  # viraria "//scooters" e a API responderia 404.
  value = trimsuffix(aws_apigatewayv2_stage.default.invoke_url, "/")
}

output "scooters_table" {
  description = "Nome da tabela DynamoDB de status das scooters."
  value       = aws_dynamodb_table.scooters.name
}
