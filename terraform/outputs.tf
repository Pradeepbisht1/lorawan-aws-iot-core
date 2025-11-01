output "lambda_function_arn" {
  description = "ARN of the LoRaWAN decoder Lambda function"
  value       = aws_lambda_function.lorawan_decoder.arn
}

output "lambda_function_name" {
  description = "Name of the LoRaWAN decoder Lambda function"
  value       = aws_lambda_function.lorawan_decoder.function_name
}

output "timestream_database_name" {
  description = "Name of the Timestream database"
  value       = aws_timestreamwrite_database.sensor_db.database_name
}

output "timestream_table_name" {
  description = "Name of the Timestream table"
  value       = aws_timestreamwrite_table.sensor_table.table_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.device_metadata.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.device_metadata.arn
}

output "lorawan_gateway_id" {
  description = "ID of the LoRaWAN gateway"
  value       = aws_iot_wireless_gateway.lorawan_gateway.id
}

output "lorawan_gateway_arn" {
  description = "ARN of the LoRaWAN gateway"
  value       = aws_iot_wireless_gateway.lorawan_gateway.arn
}

output "lorawan_device_id" {
  description = "ID of the LoRaWAN end device"
  value       = aws_iot_wireless_device.lorawan_device.id
}

output "lorawan_device_arn" {
  description = "ARN of the LoRaWAN end device"
  value       = aws_iot_wireless_device.lorawan_device.arn
}

output "iot_rule_name" {
  description = "Name of the IoT rule for LoRaWAN uplinks"
  value       = aws_iot_topic_rule.lorawan_uplink_rule.name
}

output "lorawan_destination_name" {
  description = "Name of the LoRaWAN destination"
  value       = aws_iot_wireless_destination.lorawan_destination.name
}

