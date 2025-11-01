terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Archive Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lorawan_decoder.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda function for LoRaWAN payload decoding
resource "aws_lambda_function" "lorawan_decoder" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-lorawan-decoder"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lorawan_decoder.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TIMESTREAM_DATABASE = aws_timestreamwrite_database.sensor_db.database_name
      TIMESTREAM_TABLE    = aws_timestreamwrite_table.sensor_table.table_name
      DYNAMODB_TABLE      = aws_dynamodb_table.device_metadata.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-lorawan-decoder"
  retention_in_days = 7
}

# Timestream Database
resource "aws_timestreamwrite_database" "sensor_db" {
  database_name = "${var.project_name}-sensor-data"

  tags = {
    Name        = "${var.project_name}-sensor-database"
    Environment = var.environment
  }
}

# Timestream Table
resource "aws_timestreamwrite_table" "sensor_table" {
  database_name = aws_timestreamwrite_database.sensor_db.database_name
  table_name    = "${var.project_name}-sensor-readings"

  retention_properties {
    magnetic_store_retention_period_in_days = 365
    memory_store_retention_period_in_hours  = 24
  }

  tags = {
    Name        = "${var.project_name}-sensor-table"
    Environment = var.environment
  }
}

# DynamoDB Table for device metadata
resource "aws_dynamodb_table" "device_metadata" {
  name           = "${var.project_name}-device-metadata"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "DevEUI"

  attribute {
    name = "DevEUI"
    type = "S"
  }

  ttl {
    attribute_name = "TTL"
    enabled        = false
  }

  tags = {
    Name        = "${var.project_name}-device-metadata"
    Environment = var.environment
  }
}

# LoRaWAN Gateway (Wireless Gateway)
resource "aws_iot_wireless_gateway" "lorawan_gateway" {
  name        = "${var.project_name}-gateway"
  description = "LoRaWAN Gateway for IN865 band (India)"

  lo_ra_wan {
    gateway_eui    = var.gateway_eui
    rf_region      = "IN865"
    join_eui_filters = []
    net_id_filters = []
  }

  tags = {
    Name        = "${var.project_name}-gateway"
    Environment = var.environment
  }
}

# LoRaWAN Destination for gateway
resource "aws_iot_wireless_destination" "lorawan_destination" {
  name = "${var.project_name}-uplink-destination"

  expression      = "true"
  expression_type = "RuleName"

  tags = {
    Name        = "${var.project_name}-uplink-destination"
    Environment = var.environment
  }
}

# LoRaWAN Device Profile
resource "aws_iot_wireless_device_profile" "lorawan_device_profile" {
  name = "${var.project_name}-device-profile"

  lo_ra_wan {
    class_b_timeout       = 1
    mac_version           = "1.0.3"
    max_duty_cycle        = 0
    max_eirp              = 14
    ping_slot_dr          = 0
    ping_slot_freq        = 0
    ping_slot_period      = 4096
    reg_params_revision   = "RP002-1.0.3"
    rf_region             = "IN865"
    supports_32_bit_f_cnt = false
    supports_class_b      = false
    supports_class_c      = false
    supports_join         = true
  }

  tags = {
    Name        = "${var.project_name}-device-profile"
    Environment = var.environment
  }
}

# LoRaWAN End Device
resource "aws_iot_wireless_device" "lorawan_device" {
  name                = "${var.project_name}-end-device"
  type                = "LoRaWAN"
  destination_name    = aws_iot_wireless_destination.lorawan_destination.name

  lo_ra_wan {
    dev_eui  = var.dev_eui
    device_profile_id = aws_iot_wireless_device_profile.lorawan_device_profile.id
    otaa_v1_0_1 {
      app_key = var.app_key
      app_eui = var.app_eui
    }
    rf_region = "IN865"
  }

  tags = {
    Name        = "${var.project_name}-end-device"
    Environment = var.environment
    DevEUI      = var.dev_eui
  }
}

# IoT Topic Rule for LoRaWAN uplinks
resource "aws_iot_topic_rule" "lorawan_uplink_rule" {
  name        = "${var.project_name}-lorawan-uplink-rule"
  enabled     = true
  description = "Process LoRaWAN uplink messages and invoke decoder Lambda"

  sql         = "SELECT * FROM '$aws/things/+/wireless/lorawan/uplink'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.lorawan_decoder.arn
  }

  error_action {
    cloudwatch_metrics {
      metric_name      = "LoRaWAN_Uplink_Error"
      metric_namespace = var.project_name
      metric_unit      = "Count"
      metric_value     = "1"
      role_arn         = aws_iam_role.iot_rule_role.arn
    }
  }

  depends_on = [
    aws_lambda_function.lorawan_decoder,
    aws_iot_wireless_device.lorawan_device
  ]
}

# Grant IoT permission to invoke Lambda
resource "aws_lambda_permission" "allow_iot" {
  statement_id  = "AllowExecutionFromIoT"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lorawan_decoder.function_name
  principal     = "iot.amazonaws.com"
  source_arn    = "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${aws_iot_topic_rule.lorawan_uplink_rule.name}"

  depends_on = [
    aws_iot_topic_rule.lorawan_uplink_rule
  ]
}

