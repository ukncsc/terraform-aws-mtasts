variable "domains" {
    description = "The list of domains for which to create an MTA-STS policy"
    type = list
    default = [ "example.com" ]
}

variable "delegated-domains" {
    description = "A list of domains on which this code has been previously run, and the created mta-sts zone delegated by adding NS records to the main zone"
    type = list
    default = [ ]
}

variable "policy" {
    description = "The MTA-STS policy to apply, valid options are testing or enforce"
    type = string
    default = "testing"
}

