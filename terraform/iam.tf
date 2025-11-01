# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
  }
}

# IAM Policy for Lambda to write to Timestream
resource "aws_iam_role_policy" "lambda_timestream" {
  name = "${var.project_name}-lambda-timestream-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "timestream:WriteRecords",
          "timestream:DescribeEndpoints",
          "timestream:DescribeDatabase",
          "timestream:DescribeTable"
        ]
        Resource = [
          "${aws_timestreamwrite_database.sensor_db.arn}/*",
          "arn:aws:timestream:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${aws_timestreamwrite_database.sensor_db.database_name}",
          "arn:aws:timestream:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${aws_timestreamwrite_database.sensor_db.database_name}/table/*"
        ]
      }
    ]
  })
}

# IAM Policy for Lambda to write to DynamoDB
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.project_name}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.device_metadata.arn
        ]
      }
    ]
  })
}

# IAM Policy for Lambda to write CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Role for IoT Rule error actions
resource "aws_iam_role" "iot_rule_role" {
  name = "${var.project_name}-iot-rule-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-iot-rule-role"
    Environment = var.environment
  }
}

# IAM Policy for IoT Rule to write CloudWatch Metrics
resource "aws_iam_role_policy" "iot_cloudwatch_metrics" {
  name = "${var.project_name}-iot-cloudwatch-metrics-policy"
  role = aws_iam_role.iot_rule_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.project_name
          }
        }
      }
    ]
  })
}

