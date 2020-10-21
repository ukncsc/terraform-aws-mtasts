data "template_file" "instructions_template" {
  count  =  var.delegated || length(var.zone_id) >0 ? 0:1
  template = <<EOF

Create the following DNS entries in your $${domain} zone:

mta-sts.$${domain} NS record pointing to:
$${mta-sts-ns}

$${mta-sts-cname-record} CNAME pointing to:
$${mta-sts-record}

$${tls-reporting-text}

Once the delegation is complete set the variable delegated = true

  EOF
  vars = {
    domain = var.domain
    mta-sts-ns = join("\n",flatten(aws_route53_zone.mta-sts-zone.*.name_servers))
    mta-sts-cname-record = local.mta-sts-cname-record
    mta-sts-record = local.mta-sts-record
    tls-reporting-text =   length(var.reporting_email) > 0 ? "${local.tls-rpt-cname-record} CNAME pointing to:\n${local.tls-rpt-record}" : ""
  }
}

output "Instructions" {
    value = join("",flatten(data.template_file.instructions_template.*.rendered))
}

