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

data "template_file" "details_template" {
  count  =  var.delegated || length(var.zone_id) >0 ? 1:0
  template = <<EOF

DNS Records:
$${mta-sts-delegation}
$${tls-rpt-delegation}
$${mta-sts-ns-delegation}

MTA-STS Policy:
$${policy}

$${mta-sts}

$${tls-rpt}
  EOF
  vars = {
    domain = var.domain
    policy = local.policy
    mta-sts = "${local.mta-sts-cname-record} record value:\n${local.mta-sts-record-value}"
    tls-rpt = length(var.reporting_email) > 0 ? "${local.tls-rpt-cname-record} record value:\n${local.tls-rpt-record-value}" : ""
    mta-sts-delegation = "${local.mta-sts-cname-record} CNAME ${join("",data.dns_cname_record_set._mta-sts.*.cname)}"
    tls-rpt-delegation = "${local.tls-rpt-cname-record} CNAME ${join("",data.dns_cname_record_set.tls-rpt.*.cname)}"
    mta-sts-ns-delegation = "${local.policydomain} NS ${join(",",flatten(data.dns_ns_record_set.mta-sts.*.nameservers))}"

  }
}


output "output" {
    value = join("",flatten((concat(data.template_file.details_template.*.rendered,data.template_file.instructions_template.*.rendered))))
}

data "dns_cname_record_set" "_mta-sts" {
  count  =  var.delegated && var.dns-delegation-checks ? 1:0
  host = local.mta-sts-cname-record
}

data "dns_cname_record_set" "tls-rpt" {
  count  =  length(var.reporting_email) > 0 && var.delegated && var.dns-delegation-checks ? 1:0
  host = local.tls-rpt-cname-record
}

data "dns_ns_record_set" "mta-sts" {
  count  =  var.delegated && var.dns-delegation-checks ? 1:0
  host = local.policydomain
}