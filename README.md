# MTA-STS/TLS-RPT AWS Module

This repo contains a module and example code for deploying an [MTS-STS](https://tools.ietf.org/html/rfc8461) and [TLS-RPT](https://tools.ietf.org/html/rfc8460) policy for a domin in AWS using [Terraform](https://www.terraform.io/).

This consists of using AWS API Gateway with a Custom Domain to host the MTA-STS policy, with a TLS certificate provided by AWS ACM. It uses Route53 to configure the DNS portions of both MTA-STS and TLS-RPT.

## How to use the example code

There are three examples for using the module in different ways.

## Guided Automatic /examples/guided-automatic

This method creates a new subdomain in Route53 for each domain called mta-sts, this will need to be delegated from your existing DNS zone for that domain.
CNAMES are used to point _mta-sts.domain and _smtp._tls.domain to records in this new mta-sts zone, these will also need to be created in your existing DNS.

To reduce the number of manual steps in this mode, there is a two stage apply process, to avoid this please use the manual mode.

1) Edit the configuration.tf file (or pass in a tfvars file)
   Add your list of domains to the domains variable.

2) run terraform init, then terraform apply in that directory
   
3) Review the output, there are instructions for creating all of the DNS entries in your existing main DNS zone for each domain

4) Once the records are created for each domain, add the domain to the delegated-domains variable in configuration.tf (or tfvars)
   
5) run terraform apply again, request and validate certificates and complete the process
   
6) Once you have checked all of your mail servers for TLS 1.2 and valid certificates, change the policy to enforce in cofnfiguration.tf (or tfvars)
   
## Manual mode - delegated from an existing DNS zone /examples/delegated-subdomain

This method creates a new subdomain in Route53 for each domain called mta-sts, this will need to be delegated from your existing DNS zone for that domain.
CNAMES are used to point _mta-sts.domain and _smtp._tls.domain to records in this new mta-sts zone, these will also need to be created in your existing DNS.

The end result is the same as the automatic mode but uses more declarative terraform and a single step apply.

1) Create an mta-sts subdomain Route53 zone for each of your domains
2) Create NS records in your main domain zone for the new subdomain
3) Create a CNAME record from _mta-sts.domain to _mta-sts.mta-sts.domain
4) Create a CNAME record from _smtp._tls.domain to _smtp._tls.mta-sts.domain
5) Modify the example code for your domain(s)
6) terraform init/plan/apply


## Manual mode - main domain DNS zone is hosted in Route53 /examples/domain-in-route53

This option is the simplest and does rely on delegation or CNAMEs, however it does require that the main DNS zone for that domain is already hosted in Route53 and the account used has permission to modify that zone.

1) Find the Route53 zone id for your domain in the AWS dashboard
2) Modify the example code with your domain name and zone id
3) terraform init/plan/apply


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

