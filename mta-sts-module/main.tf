locals {
  policydomain = "mta-sts.${var.domain}"
  mta-sts-cname-record = "_mta-sts.${var.domain}"
  tls-rpt-cname-record = "_smtp._tls.${var.domain}"
  mta-sts-record = "_mta-sts.mta-sts.${var.domain}"
  tls-rpt-record = "_smtp._tls.mta-sts.${var.domain}"
  mta-sts-record-value = "v=STSv1; id=${local.policyhash}"
  tls-rpt-record-value = "v=TLSRPTv1;rua=mailto:${var.reporting_email}"
  route53_zone_id = element(concat(data.aws_route53_zone.zone.*.id,aws_route53_zone.mta-sts-zone.*.id,data.aws_route53_zone.zone.*.id),0)

  policy =  <<EOF
version: STSv1
mode: ${var.mode}
${join("\n",local.formattedmxlist)}
max_age: ${var.max_age}
EOF
  policyhash   = md5(format("%s%s%s", join("", var.mx), var.mode, var.max_age))
  mxlist = (length(var.mx) > 0 ? var.mx : data.dns_mx_record_set.mx.mx.*.exchange)
  formattedmxlist = [
  for mx in local.mxlist: 
  "mx: ${trimsuffix(mx,".")}"
  ]
}

resource "aws_acm_certificate" "cert" {
  domain_name       = local.policydomain
  validation_method = "DNS"
  tags              = var.tags
}


data "aws_route53_zone" "zone" {
   count = length(var.zone_id) >0 ? 1:0
  zone_id = var.zone_id
}


resource "aws_route53_zone" "mta-sts-zone" {
  count = length(var.zone_id) == 0 && var.create-subdomain ? 1:0
  name = local.policydomain
}

data "aws_route53_zone" "mta-sts-zone" {
  count = length(var.zone_id) >0  && !var.create-subdomain ? 1:0
  name = local.policydomain
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
  name    = dvo.resource_record_name
  type    = dvo.resource_record_type
  record = dvo.resource_record_value
    }
  }
  allow_overwrite = true
  name = each.value.name
  records = [each.value.record]
  type = each.value.type
  zone_id = element(concat(data.aws_route53_zone.zone.*.id,aws_route53_zone.mta-sts-zone.*.id),0)
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  count = length(var.zone_id) > 0 || var.delegated ? 1:0
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation: record.fqdn]
}

resource "aws_api_gateway_rest_api" "mtastspolicyapi" {
  name = var.domain

  endpoint_configuration {
    types = ["REGIONAL"]
  }
  tags = var.tags
}

resource "aws_api_gateway_resource" "wellknownresource" {
  rest_api_id = aws_api_gateway_rest_api.mtastspolicyapi.id
  parent_id   = aws_api_gateway_rest_api.mtastspolicyapi.root_resource_id
  path_part   = ".well-known"
}

resource "aws_api_gateway_resource" "policyresource" {
  rest_api_id = aws_api_gateway_rest_api.mtastspolicyapi.id
  parent_id   = aws_api_gateway_resource.wellknownresource.id
  path_part   = "mta-sts.txt"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.mtastspolicyapi.id
  resource_id   = aws_api_gateway_resource.policyresource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id          = aws_api_gateway_rest_api.mtastspolicyapi.id
  resource_id          = aws_api_gateway_resource.policyresource.id
  http_method          = aws_api_gateway_method.method.http_method
  type                 = "MOCK"
  passthrough_behavior = "NEVER"

  request_templates = {
    "application/json" = <<EOF
{
   "statusCode" : 200
}
EOF

  }
}

resource "aws_api_gateway_method_response" "twohundred" {
  rest_api_id = aws_api_gateway_rest_api.mtastspolicyapi.id
  resource_id = aws_api_gateway_resource.policyresource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"
}

data "dns_mx_record_set" "mx" {
  domain = var.domain
}

resource "aws_api_gateway_integration_response" "integrationresponse" {
  rest_api_id = aws_api_gateway_rest_api.mtastspolicyapi.id
  resource_id = aws_api_gateway_resource.policyresource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = aws_api_gateway_method_response.twohundred.status_code

  # Transforms the backend JSON response to XML
  response_templates = {
    "text/plain" = <<EOF
#set($context.responseOverride.header.Content-Type='text/plain')
${local.policy}
EOF

  }

  depends_on = [aws_api_gateway_integration.integration]
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.integration]

  rest_api_id = aws_api_gateway_rest_api.mtastspolicyapi.id
  stage_name  = "deployed"

  # Include policyhash so there's a new deployment when the policy changes
  variables = {
    policyhash = local.policyhash
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_domain_name" "domain" {
  count = length(var.zone_id) > 0 || var.delegated ? 1:0
  domain_name              = local.policydomain
  regional_certificate_arn = join("",aws_acm_certificate_validation.cert.*.certificate_arn)

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "basepathmapping" {
  count = length(var.zone_id) > 0 || var.delegated ? 1:0
  api_id      = aws_api_gateway_rest_api.mtastspolicyapi.id
  stage_name  = aws_api_gateway_deployment.deployment.stage_name
  domain_name = join("",aws_api_gateway_domain_name.domain.*.domain_name)
}

resource "aws_route53_record" "apigatewaypointer" {
  count = length(var.zone_id) > 0 || var.delegated ? 1:0
  name    = join("",flatten(aws_api_gateway_domain_name.domain.*.domain_name))
  type    = "A"
  zone_id = local.route53_zone_id

  alias {
    evaluate_target_health = true
    name                   = join("", flatten(aws_api_gateway_domain_name.domain.*.regional_domain_name))
    zone_id                = join("", flatten(aws_api_gateway_domain_name.domain.*.regional_zone_id))
  }
}

resource "aws_route53_record" "smtptlsreporting" {
  zone_id = local.route53_zone_id
  name    = local.tls-rpt-record
  type    = "TXT"
  ttl     = "300"
  count   = length(var.reporting_email) > 0 ? 1 : 0

  records = [
    local.tls-rpt-record-value
  ]
}

resource "aws_route53_record" "mtastspolicydns" {
  zone_id = local.route53_zone_id
  name    = local.mta-sts-record
  type    = "TXT"
  ttl     = "300"

  records = [
    local.mta-sts-record-value
  ]
}

