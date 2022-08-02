# MTA-STS/TLS-RPT AWS Module

This repo contains a module for deploying an [MTS-STS](https://tools.ietf.org/html/rfc8461) and [TLS-RPT](https://tools.ietf.org/html/rfc8460) policy for a domin in AWS using [Terraform](https://www.terraform.io/).

This consists of using CloudFront/S3 with a Custom Domain to host the MTA-STS policy, with a TLS certificate provided by AWS ACM. It uses Route53 to configure the DNS portions of both MTA-STS and TLS-RPT.

## How to use this Module

This module assumes AWS Account with access to Route53, CloudFront, S3, and ACM, which also hosts the DNS (in Route53) for the domain you wish to deploy MTA-STS/TLS-RPT.
The providers are defined here to allow resources to be provisioned in both `us-east-1` and a local region (`eu-west-2` in this example). This method also allows additional providers to be defined for additional AWS accounts / profiles, if required.

```terraform
provider "aws" {
  alias                    = "useast1"
  region                   = "us-east-1"
  shared_config_files      = ["___/.aws/conf"]
  shared_credentials_files = ["___/.aws/creds"]
  profile                  = "myprofile"
}

provider "aws" {
  alias                    = "myregion"
  region                   = "eu-west-2"
  shared_config_files      = ["___/.aws/conf"]
  shared_credentials_files = ["___/.aws/creds"]
  profile                  = "myprofile"
}

module "mtastspolicy_examplecom" {
  source          = "github.com/ukncsc/terraform-aws-mtasts"
  domain          = "example.com"
  mx              = ["mail.example.com"]
  mode            = "testing"
  reporting_email = "tlsreporting@example.com"
  
  providers = {
    aws.useast1 = aws.useast1
    aws.account = aws.myregion
  }

}
```