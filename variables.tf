variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile name from ~/.aws/credentials (managed by Doormat)"
  type        = string
  default     = "default"
}

variable "storage_prefix" {
  type        = string
  description = "Prefix for storage account name (must be lowercase, alphanumeric, 3-24 chars)"
}

variable "azure_location" {
  type        = string
  description = "Azure region for resources"
  default     = "East US"
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID"
}