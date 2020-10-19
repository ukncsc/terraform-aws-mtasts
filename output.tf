data "template_file" "instructions_template" {
  count  = var.delegated || length(var.zone_id) >0 ? 0:1
  template = <<EOF

Create the following NS entries in your $${domain} zone:

mta-sts.$${domain} pointing to:
$${mta-sts-policy-ns}

_mta-sts.$${domain} pointing to:
$${mta-sts-record-ns}

$${tls-reporting-text}
$${tls-reporting-ns}

Once the delegation is complete set the variable delegated = true

  EOF
  vars = {
    domain = var.domain
    mta-sts-policy-ns = join("\n",flatten(aws_route53_zone.mta-sts-policy-zone.*.name_servers))
    mta-sts-record-ns = join("\n",flatten(aws_route53_zone.mta-sts-record-zone.*.name_servers))
    tls-reporting-ns = join("\n",flatten(aws_route53_zone.tls-reporting-zone.*.name_servers))
    tls-reporting-text = length(flatten(aws_route53_zone.tls-reporting-zone.*.name_servers)) > 0 ? "_tls-mta-sts.$${domain} pointing to:" : ""

  }
}

output "Instructions" {
    value = join("",flatten(data.template_file.instructions_template.*.rendered))


}
 
