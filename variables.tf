variable "zone_id" {
  type        = "string"
  description = "Route53 zone hosting the domain MTA-STS/TLS-RPT is being deployed for."
}

variable "domain" {
  type        = "string"
  description = "The domain MTA-STS/TLS-RPT is being deployed for."
}

variable "mode" {
  type        = "string"
  default     = "testing"
  description = "MTA-STS policy 'mode'. Either 'testing' or 'enforce'."
}

variable "max_age" {
  type        = "string"
  default     = "86400"
  description = "MTA-STS max_age. Time in seconds the policy should be cached. Default is 1 day"
}

variable "mx" {
  type        = "list"
  description = "'mx' value for MTA-STS policy. List of MX hostnames to be included in MTA-STS policy"
}

variable "reporting_email" {
  type        = "string"
  default     = ""
  description = "(Optional) Email to use for TLS-RPT reporting."
}
