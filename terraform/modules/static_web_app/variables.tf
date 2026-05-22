variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "suffix" { type = string }
variable "tags" { type = map(string) }

variable "sku_tier" {
  type    = string
  default = "Standard"
}
