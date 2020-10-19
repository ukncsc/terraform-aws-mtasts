variable "zone_id" {
  type        = string
  description = "Route53 zone hosting the domain MTA-STS/TLS-RPT is being deployed for."
  default = ""
}

variable "domain" {
  type        = string
  description = "The domain MTA-STS/TLS-RPT is being deployed for."
}

variable "mode" {
  type        = string
  default     = "testing"
  description = "MTA-STS policy 'mode'. Either 'testing' or 'enforce'."
}

variable "max_age" {
  type        = string
  default     = "86400"
  description = "MTA-STS max_age. Time in seconds the policy should be cached. Default is 1 day"
}

variable "mx" {
  type        = list(string)
  description = "'mx' value for MTA-STS policy. List of MX hostnames to be included in MTA-STS policy"
  default = []
}

variable "reporting_email" {
  type        = string
  default     = ""
  description = "(Optional) Email to use for TLS-RPT reporting."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "(Optional) tags to apply to underlying resources"
}

variable "delegated" {
  type = bool
  default = false
  description = "Set to true after the route53 zones have been delegated from the main domains so that certificate validation can succeed"
}
