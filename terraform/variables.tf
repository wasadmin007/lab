variable "project_name" {
  description = "Short project identifier used in resource naming (lowercase alphanumeric)"
  type        = string
  default     = "empportal"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default = {
    project    = "employee-portal"
    managed_by = "terraform"
  }
}

variable "cosmos_throughput" {
  description = "Cosmos DB container throughput in RU/s"
  type        = number
  default     = 400
}

variable "static_web_app_sku_tier" {
  description = "Static Web App SKU (Free or Standard; Standard required for custom domains)"
  type        = string
  default     = "Standard"
}
