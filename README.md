# AWS IoT LoRaWAN Infrastructure with Terraform

This Terraform configuration sets up a complete AWS IoT infrastructure for LoRaWAN devices using the IN865 band (India region). The setup includes device registration, gateway configuration, payload decoding, and data storage in Timestream and DynamoDB.

## Architecture Overview

```
LoRaWAN Device → Gateway → AWS IoT Core → IoT Rule → Lambda Function
                                                       ↓
                                    ┌──────────────────┼──────────────────┐
                                    ↓                  ↓                  ↓
                              Timestream        DynamoDB          CloudWatch Logs
                            (Sensor Data)    (Device Metadata)      (Logging)
```

## Features

- **LoRaWAN Gateway Registration**: Register a LoRaWAN gateway for IN865 band (India)
- **OTAA Device Onboarding**: Configure end devices using Over-The-Air Activation
- **Payload Decoding**: Lambda function to decode binary LoRaWAN payloads to JSON
- **Time-Series Storage**: Amazon Timestream for sensor readings
- **Device Metadata**: Amazon DynamoDB for device metadata and last-seen timestamps
- **Automated Processing**: IoT Rule automatically processes uplink messages
- **IAM Security**: Least-privilege IAM roles and policies

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with credentials
4. **Python 3.11** (for Lambda function)
5. **LoRaWAN Device Details**:
   - Gateway EUI (16 hex characters)
   - Device EUI (16 hex characters)
   - Application EUI (16 hex characters)
   - Application Key (32 hex characters)

## Quick Start

### 1. Configure Variables

Copy the example variables file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

```hcl
aws_region   = "ap-south-1"
project_name = "lorawan-iot"
environment  = "dev"

gateway_eui = "YOUR_GATEWAY_EUI"
dev_eui    = "YOUR_DEVICE_EUI"
app_eui    = "YOUR_APPLICATION_EUI"
app_key    = "YOUR_32_CHARACTER_APP_KEY"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

When prompted, type `yes` to confirm.

### 5. Verify Resources

After deployment, check the outputs:

```bash
terraform output
```

## Configuration

### LoRaWAN Payload Decoder

The Lambda function (`lambda/lorawan_decoder.py`) includes a sample decoder that expects:
- **Bytes 0-1**: Temperature (signed int16, divided by 100)
- **Bytes 2-3**: Humidity (unsigned int16, divided by 100)

**Customize the decoder** in `lambda/lorawan_decoder.py` based on your device's payload format.

### Device Profile

The default device profile is configured for:
- **MAC Version**: 1.0.3 (LoRaWAN 1.0)
- **RF Region**: IN865 (India)
- **Join Mode**: OTAA enabled
- **Max EIRP**: 14 dBm

Modify `aws_iot_wireless_device_profile.lorawan_device_profile` in `main.tf` if needed.

## Resources Created

### AWS IoT
- LoRaWAN Gateway (IN865 band)
- LoRaWAN Destination
- LoRaWAN Device Profile
- LoRaWAN End Device (OTAA)
- IoT Topic Rule for uplink processing

### Compute
- Lambda Function (Python 3.11)
- CloudWatch Log Group

### Storage
- Timestream Database (`{project_name}-sensor-data`)
- Timestream Table (`{project_name}-sensor-readings`)
- DynamoDB Table (`{project_name}-device-metadata`)

### IAM
- Lambda execution role with policies for:
  - Timestream write access
  - DynamoDB read/write access
  - CloudWatch Logs
- IoT Rule role for CloudWatch Metrics

## Data Flow

1. **LoRaWAN Device** sends uplink message via **Gateway**
2. **AWS IoT Core** receives the message and triggers the **IoT Rule**
3. **IoT Rule** invokes the **Lambda Function** with the payload
4. **Lambda Function**:
   - Decodes the binary payload to JSON
   - Writes sensor readings to **Timestream**
   - Updates device metadata in **DynamoDB**
5. **CloudWatch** logs all processing steps

## Querying Data

### Timestream Query Example

```sql
SELECT 
    DevEUI,
    measure_name,
    measure_value::double as value,
    time
FROM "{database_name}"."{table_name}"
WHERE time > ago(1h)
ORDER BY time DESC
```

### DynamoDB Query

Use AWS CLI or SDK to query device metadata:

```bash
aws dynamodb get-item \
    --table-name lorawan-iot-device-metadata \
    --key '{"DevEUI": {"S": "YOUR_DEV_EUI"}}'
```

## Customization

### Modify Payload Decoder

Edit `lambda/lorawan_decoder.py` and update the `decode_lorawan_payload()` function to match your device's payload format.

### Add Additional Sensors

1. Update the decoder to extract new sensor values
2. Add new `MeasureName` entries in the Timestream write operation
3. Update DynamoDB metadata structure if needed

### Change Retention Policies

Modify Timestream retention properties in `main.tf`:

```hcl
retention_properties {
  magnetic_store_retention_period_in_days = 365
  memory_store_retention_period_in_hours = 24
}
```

## Troubleshooting

### Lambda Function Not Invoked

1. Check IoT Rule status: `aws iot get-topic-rule --rule-name {rule_name}`
2. Verify Lambda permissions: Check CloudWatch Logs for errors
3. Test the Lambda function directly with a sample event

### Payload Decoding Errors

1. Check CloudWatch Logs: `/aws/lambda/{function_name}`
2. Verify payload format matches the decoder expectations
3. Update decoder function if device uses a different format

### Device Not Joining

1. Verify device credentials (DevEUI, AppEUI, AppKey)
2. Check device profile configuration
3. Ensure gateway is properly registered and online

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will delete all data in Timestream and DynamoDB tables. Export data first if needed.

## Security Notes

- All sensitive variables (DevEUI, AppEUI, AppKey) are marked as `sensitive` in Terraform
- IAM policies follow least-privilege principle
- Use AWS Secrets Manager for production deployments
- Enable encryption at rest for Timestream and DynamoDB

## Cost Optimization

- DynamoDB uses `PAY_PER_REQUEST` billing mode
- Timestream retention can be adjusted based on data requirements
- Lambda memory and timeout can be optimized based on payload size
- CloudWatch Logs retention is set to 7 days (adjustable)

## Support

For issues or questions:
- Check AWS IoT Core documentation
- Review Terraform AWS provider documentation
- Check Lambda function logs in CloudWatch

## License

This configuration is provided as-is for educational and development purposes.

