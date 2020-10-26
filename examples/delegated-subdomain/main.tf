module "mtastspolicy_examplecom" {
  source          = "github.com/ukncsc/terraform-aws-mtasts/mta-sts-module"
  domain          = "example.com"
  mx              = ["mail.example.com"]        // Optional - default looks up MX records for the domain in DNS 
  mode            = "testing"                   // Optional - default is testing
  reporting_email = "tlsreporting@example.com"  // Optional - default is no TLS-RPT record
  delegated = false                             // Optional - default is false. Change this to true once the new zones are delegated from your domain
  create_subdomain = false                      // Optional - default is true. When set to false you must create the subdomain mta-sts manually but it is a single step apply.
}

output "output" {
  value = module.mtastspolicy_examplecom.output
}