# MTA-STS/TLS-RPT AWS Module

This repo contains a module for deploying an [MTS-STS](https://tools.ietf.org/html/rfc8461) and [TLS-RPT](https://tools.ietf.org/html/rfc8460) policy for a domin in AWS using [Terraform](https://www.terraform.io/).

This consists of using CloudFront/S3 with a Custom Domain to host the MTA-STS policy, with a TLS certificate provided by AWS ACM. It uses Route53 to configure the DNS portions of both MTA-STS and TLS-RPT.

## How to use this Module

This module assumes AWS Account with access to Route53, CloudFront, S3, and ACM, which also hosts the DNS (in Route53) for the domain you wish to deploy MTA-STS/TLS-RPT.

```terraform
module "mtastspolicy_examplecom" {
  source          = "github.com/ukncsc/terraform-aws-mtasts"
  zone_id         = "Z00AAAAAAA0A0A"
  domain          = "example.com"
  mx              = ["mail.example.com"]
  mode            = "testing"
  reporting_email = "tlsreporting@example.com"
}
```

## Pre-existing SMTP records

When consuming this module for an email domain that already has TLS enabled, there is a good chance the resource below will have already been created:

```terraform
resource "aws_route53_record" "smtptlsreporting" {
  ...
}
```

In order to resolve this, please import the existing Route53 record into the remote state of the repo that is consuming this module.

*Please note: the ability to destroy this particular record has been disabled as it could lead to this module destroying pre-existing SMTP records*
*If you wish to destroy certain instances of MTA-STS, please remove the SMTP record from the state before running destroy*