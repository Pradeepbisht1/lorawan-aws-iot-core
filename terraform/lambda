"""
LoRaWAN payload decoder Lambda function.
Decodes binary LoRaWAN payloads and writes to Timestream and DynamoDB.
"""

import json
import os
import boto3
from datetime import datetime
from decimal import Decimal
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
timestream_write = boto3.client('timestream-write')
dynamodb = boto3.client('dynamodb')

# Environment variables
TIMESTREAM_DATABASE = os.environ.get('TIMESTREAM_DATABASE')
TIMESTREAM_TABLE = os.environ.get('TIMESTREAM_TABLE')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')


def decode_lorawan_payload(payload_hex):
    """
    Decode LoRaWAN binary payload to JSON.
    This is a sample decoder - customize based on your device's payload format.
    
    Example: Assuming a simple format with temperature (2 bytes) and humidity (2 bytes)
    """
    try:
        # Convert hex string to bytes
        payload_bytes = bytes.fromhex(payload_hex.replace(' ', ''))
        
        if len(payload_bytes) < 4:
            logger.warning(f"Payload too short: {len(payload_bytes)} bytes")
            return {"error": "payload_too_short"}
        
        # Example decoder: first 2 bytes = temperature (signed int16, divide by 100)
        # next 2 bytes = humidity (unsigned int16, divide by 100)
        temperature_raw = int.from_bytes(payload_bytes[0:2], byteorder='big', signed=True)
        humidity_raw = int.from_bytes(payload_bytes[2:4], byteorder='big', signed=False)
        
        temperature = temperature_raw / 100.0
        humidity = humidity_raw / 100.0
        
        # Extract any additional fields if present
        additional_data = {}
        if len(payload_bytes) > 4:
            # Add more decoding logic here based on your device specification
            additional_data['raw_remaining'] = payload_bytes[4:].hex()
        
        return {
            "temperature": temperature,
            "humidity": humidity,
            "timestamp": datetime.utcnow().isoformat(),
            **additional_data
        }
    except Exception as e:
        logger.error(f"Error decoding payload: {str(e)}")
        return {"error": str(e), "raw_payload": payload_hex}


def write_to_timestream(dev_eui, decoded_data):
    """Write decoded sensor data to Timestream."""
    try:
        records = []
        
        # Write temperature if present
        if 'temperature' in decoded_data and 'error' not in decoded_data:
            records.append({
                'Dimensions': [
                    {'Name': 'DevEUI', 'Value': dev_eui}
                ],
                'MeasureName': 'temperature',
                'MeasureValue': str(decoded_data['temperature']),
                'MeasureValueType': 'DOUBLE',
                'Time': str(int(datetime.utcnow().timestamp() * 1000))
            })
        
        # Write humidity if present
        if 'humidity' in decoded_data and 'error' not in decoded_data:
            records.append({
                'Dimensions': [
                    {'Name': 'DevEUI', 'Value': dev_eui}
                ],
                'MeasureName': 'humidity',
                'MeasureValue': str(decoded_data['humidity']),
                'MeasureValueType': 'DOUBLE',
                'Time': str(int(datetime.utcnow().timestamp() * 1000))
            })
        
        if records:
            timestream_write.write_records(
                DatabaseName=TIMESTREAM_DATABASE,
                TableName=TIMESTREAM_TABLE,
                Records=records
            )
            logger.info(f"Wrote {len(records)} records to Timestream for DevEUI {dev_eui}")
    except Exception as e:
        logger.error(f"Error writing to Timestream: {str(e)}")
        raise


def write_to_dynamodb(dev_eui, decoded_data, metadata):
    """Update device metadata and last-seen timestamp in DynamoDB."""
    try:
        current_time = int(datetime.utcnow().timestamp())
        
        # Prepare update expression
        update_expression = "SET lastSeen = :timestamp, lastPayload = :payload"
        expression_values = {
            ':timestamp': {'N': str(current_time)},
            ':payload': {'S': json.dumps(decoded_data)}
        }
        
        # Add gateway information if available
        if 'WirelessMetadata' in metadata and 'LoRaWAN' in metadata['WirelessMetadata']:
            lorawan_meta = metadata['WirelessMetadata']['LoRaWAN']
            if 'GatewayEui' in lorawan_meta:
                update_expression += ", gatewayEui = :gateway"
                expression_values[':gateway'] = {'S': lorawan_meta['GatewayEui']}
            if 'DataRate' in lorawan_meta:
                update_expression += ", dataRate = :datarate"
                expression_values[':datarate'] = {'N': str(lorawan_meta['DataRate'])}
            if 'Frequency' in lorawan_meta:
                update_expression += ", frequency = :freq"
                expression_values[':freq'] = {'N': str(lorawan_meta['Frequency'])}
        
        # Add decoded sensor values
        if 'temperature' in decoded_data and 'error' not in decoded_data:
            update_expression += ", lastTemperature = :temp"
            expression_values[':temp'] = {'N': str(decoded_data['temperature'])}
        
        if 'humidity' in decoded_data and 'error' not in decoded_data:
            update_expression += ", lastHumidity = :hum"
            expression_values[':hum'] = {'N': str(decoded_data['humidity'])}
        
        dynamodb.update_item(
            TableName=DYNAMODB_TABLE,
            Key={'DevEUI': {'S': dev_eui}},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values
        )
        
        logger.info(f"Updated DynamoDB metadata for DevEUI {dev_eui}")
    except Exception as e:
        logger.error(f"Error writing to DynamoDB: {str(e)}")
        # Don't raise - metadata update failure shouldn't block processing


def lambda_handler(event, context):
    """
    Main Lambda handler for LoRaWAN uplink processing.
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract LoRaWAN data from IoT Core message
        # The event structure from IoT Core varies, so we'll handle common formats
        payload_hex = None
        dev_eui = None
        metadata = {}
        
        # Try different event formats
        if 'payload' in event:
            payload_hex = event['payload']
        elif 'PayloadData' in event:
            payload_hex = event['PayloadData']
        elif 'wirelessMetadata' in event and 'LoRaWAN' in event['wirelessMetadata']:
            lorawan = event['wirelessMetadata']['LoRaWAN']
            payload_hex = event.get('payload', lorawan.get('PayloadData', ''))
        else:
            # Handle IoT Core rule SQL result format
            if isinstance(event, list) and len(event) > 0:
                event = event[0]
            
            payload_hex = event.get('payload') or event.get('PayloadData') or event.get('payload_data', '')
        
        # Extract DevEUI
        if 'WirelessMetadata' in event:
            metadata = event['WirelessMetadata']
            if 'LoRaWAN' in metadata and 'DevEui' in metadata['LoRaWAN']:
                dev_eui = metadata['LoRaWAN']['DevEui']
        elif 'wirelessMetadata' in event:
            metadata = event['wirelessMetadata']
            if 'LoRaWAN' in metadata and 'DevEui' in metadata['LoRaWAN']:
                dev_eui = metadata['LoRaWAN']['DevEui']
        elif 'DevEUI' in event:
            dev_eui = event['DevEUI']
        
        if not payload_hex:
            logger.error("No payload data found in event")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'No payload data found'})
            }
        
        if not dev_eui:
            logger.error("No DevEUI found in event")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'No DevEUI found'})
            }
        
        # Decode the payload
        decoded_data = decode_lorawan_payload(payload_hex)
        logger.info(f"Decoded payload for DevEUI {dev_eui}: {json.dumps(decoded_data)}")
        
        # Write to Timestream
        if 'error' not in decoded_data:
            write_to_timestream(dev_eui, decoded_data)
        
        # Write to DynamoDB
        write_to_dynamodb(dev_eui, decoded_data, metadata)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'DevEUI': dev_eui,
                'decoded_data': decoded_data,
                'status': 'success'
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

