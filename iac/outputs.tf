output "lambda_registrations_arn" {
  description = "ARN de la función Lambda de Registrations"
  value       = aws_lambda_function.registrations.arn
}

output "lambda_catalogo_arn" {
  description = "ARN de la función Lambda de Catalogo"
  value       = aws_lambda_function.catalogo.arn
}

output "lambda_card_arn" {
  description = "ARN de la función Lambda de Card"
  value       = aws_lambda_function.card.arn
}

output "lambda_orderandshipping_arn" {
  description = "ARN de la función Lambda de Order and Shipping"
  value       = aws_lambda_function.orderandshipping.arn
}

output "lambda_function_names" {
  description = "Nombres de todas las funciones Lambda"
  value = {
    registrations     = aws_lambda_function.registrations.function_name
    catalogo         = aws_lambda_function.catalogo.function_name
    card             = aws_lambda_function.card.function_name
    orderandshipping = aws_lambda_function.orderandshipping.function_name
  }
}
