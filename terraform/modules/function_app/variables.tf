variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "suffix" { type = string }
variable "tags" { type = map(string) }

variable "cosmos_db_endpoint" { type = string }
variable "cosmos_db_name" { type = string }
variable "cosmos_container_name" { type = string }

variable "key_vault_id" { type = string }
variable "vnet_integration_subnet_id" { type = string }

variable "allowed_origins" {
  type    = list(string)
  default = ["*"]
}
