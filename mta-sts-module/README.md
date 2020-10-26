## How to use the Module

This module assumes AWS Account with access to Route53, API Gateway, and ACM.

It can be used in two modes, depending on whether the zone_id is defined:

1) If the domain onto which you wish to deploy MTA-STS/TLS-RPT is hosted in Route53 and this account has access:

```terraform
module "mtastspolicy_examplecom" {
  source          = "github.com/ukncsc/terraform-aws-mtasts"
  zone_id         = "Z00AAAAAAA0A0A"            // Optional - If not specified then it will run in mode 2
  domain          = "example.com"
  mx              = ["mail.example.com"]        // Optional - default looks up MX records for the domain in DNS 
  mode            = "testing"                   // Optional - default is testing
  reporting_email = "tlsreporting@example.com"  // Optional - default is no TLS-RPT record
}

output "output" {
  value = module.mtastspolicy_examplecom.output
}
```

2) If the domain onto which you wish to deploy MTA-STS/TLS-RPT is hosted elsewhere and you would like to delegate to new zones in Route53:
   
```terraform
  module "mtastspolicy_examplecom" {
  source          = "github.com/ukncsc/terraform-aws-mtasts"
  domain          = "example.com"
  mx              = ["mail.example.com"]        // Optional - default looks up MX records for the domain in DNS 
  mode            = "testing"                   // Optional - default is testing
  reporting_email = "tlsreporting@example.com"  // Optional - default is no TLS-RPT record
  delegated = false                             // Optional - default is false. Change this to true once the new zones are delegated from your domain
  create_subdomain = true                       // Optional - default is true. Change to false if creating the mta-sts zone manually, allows single step apply.
}

output "output" {
  value = module.mtastspolicy_examplecom.output
}
```
When running in Mode 2, the terraform can either be run in a one or two step process.
For a single step process the mta-sts subdomain needs to be created and delegated beforehand and the create_subdomain variable set to false.
The two step process creates the subdomain. The zone delegation instructions are shown after a terraform apply in the Instructions output variable.
If you change delegated=true before following the instructions and fully delegating the DNS then terraform will fail.

Specifying MX is optional, if they are retrieved from DNS you MUST check your policy to ensure the correct values were populated.

If a negative DNS result is cached due to delays updating the delegated zone then you may need to clear the local dns cache e.g. using ipconfig /flushdns on windows.


