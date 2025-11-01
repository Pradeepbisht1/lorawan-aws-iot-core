variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1" # Mumbai region for India
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "lorawan-iot"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "gateway_eui" {
  description = "LoRaWAN Gateway EUI (16 hex characters, e.g., AABBCCDDEEFF0011)"
  type        = string
  validation {
    condition     = can(regex("^[0-9A-Fa-f]{16}$", var.gateway_eui))
    error_message = "Gateway EUI must be exactly 16 hexadecimal characters."
  }
}

variable "dev_eui" {
  description = "LoRaWAN Device EUI (16 hex characters, e.g., 0011223344556677)"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[0-9A-Fa-f]{16}$", var.dev_eui))
    error_message = "Device EUI must be exactly 16 hexadecimal characters."
  }
}

variable "app_eui" {
  description = "LoRaWAN Application EUI (16 hex characters, e.g., 0000000000000001)"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[0-9A-Fa-f]{16}$", var.app_eui))
    error_message = "Application EUI must be exactly 16 hexadecimal characters."
  }
}

variable "app_key" {
  description = "LoRaWAN Application Key (32 hex characters for OTAA)"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[0-9A-Fa-f]{32}$", var.app_key))
    error_message = "Application Key must be exactly 32 hexadecimal characters."
  }
}
