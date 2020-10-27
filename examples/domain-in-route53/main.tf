module "mtastspolicy_examplecom" {
  source          = "github.com/ukncsc/terraform-aws-mtasts/mta-sts-module"
  zone_id         = "Z00AAAAAAA0A0A"            // Obtain this from the Route53 Console for zone example.com
  domain          = "example.com"
  mx              = ["mail.example.com"]        // Optional - default looks up MX records for the domain in DNS 
  mode            = "testing"                   // Optional - default is testing
  reporting_email = "tlsreporting@example.com"  // Optional - default is no TLS-RPT record
}
