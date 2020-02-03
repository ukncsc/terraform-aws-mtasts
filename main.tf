locals {
  policydomain = "mta-sts.${var.domain}"
  policyhash   = md5(format("%s%s%s", join("", var.mx), var.mode, var.max_age))
}

resource "aws_acm_certificate" "cert" {
  domain_name       = local.policydomain
  validation_method = "DNS"
  tags              = var.tags
}

data "aws_route53_zone" "zone" {
  zone_id = var.zone_id
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_type
  zone_id = data.aws_route53_zone.zone.id
  records = [aws_acm_certificate.cert.domain_validation_options[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
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

resource "aws_api_gateway_integration_response" "integrationresponse" {
  rest_api_id = aws_api_gateway_rest_api.mtastspolicyapi.id
  resource_id = aws_api_gateway_resource.policyresource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = aws_api_gateway_method_response.twohundred.status_code

  # Transforms the backend JSON response to XML
  response_templates = {
    "text/plain" = <<EOF
#set($context.responseOverride.header.Content-Type='text/plain')
version: STSv1
mode: ${var.mode}
${join("", formatlist("mx: %s\n", var.mx))}max_age: ${var.max_age}
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
  domain_name              = local.policydomain
  regional_certificate_arn = aws_acm_certificate_validation.cert.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "basepathmapping" {
  api_id      = aws_api_gateway_rest_api.mtastspolicyapi.id
  stage_name  = aws_api_gateway_deployment.deployment.stage_name
  domain_name = aws_api_gateway_domain_name.domain.domain_name
}

resource "aws_route53_record" "apigatewaypointer" {
  name    = aws_api_gateway_domain_name.domain.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.domain.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.domain.regional_zone_id
  }
}

resource "aws_route53_record" "smtptlsreporting" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "_smtp._tls.${var.domain}"
  type    = "TXT"
  ttl     = "300"
  count   = length(var.reporting_email) > 0 ? 1 : 0

  records = [
    "v=TLSRPTv1;rua=mailto:${var.reporting_email}",
  ]
}

resource "aws_route53_record" "mtastspolicydns" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "_mta-sts.${var.domain}"
  type    = "TXT"
  ttl     = "300"

  records = [
    "v=STSv1; id=${local.policyhash}",
  ]
}

