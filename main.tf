data "aws_caller_identity" "current" {
  provider = aws.account
}

locals {
  policydomain = "mta-sts.${var.domain}"
  policyhash   = md5(format("%s%s%s", join("", var.mx), var.mode, var.max_age))
  bucketname   = "mta-sts.${data.aws_caller_identity.current.account_id}.${var.domain}"
}

resource "aws_acm_certificate" "cert" {
  domain_name       = local.policydomain
  validation_method = "DNS"
  tags              = var.tags
  provider          = aws.useast1
}

data "aws_route53_zone" "zone" {
  zone_id = var.zone_id
}

resource "aws_route53_record" "cert_validation" {
  name    = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.zone.id
  records = [tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
  provider                = aws.useast1
}

resource "aws_s3_bucket" "policybucket" {
  bucket = local.bucketname
  acl    = "private"
}

resource "aws_s3_bucket_object" "mtastspolicyfile" {
  key          = ".well-known/mta-sts.txt"
  bucket       = aws_s3_bucket.policybucket.id
  content      = <<EOF
version: STSv1
mode: ${var.mode}
${join("", formatlist("mx: %s\n", var.mx))}max_age: ${var.max_age}
EOF
  content_type = "text/plain"
}

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.policybucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.policybucketoai.cloudfront_access_identity_path
    }
  }
  enabled = true

  aliases = [local.policydomain]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 300
    max_ttl                = 300
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }
}

resource "aws_cloudfront_origin_access_identity" "policybucketoai" {
  comment = "OAI for MTA-STS policy bucket (${var.domain})"
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.policybucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.policybucketoai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "policybucketpolicy" {
  bucket = aws_s3_bucket.policybucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_route53_record" "cloudfrontalias" {
  name    = local.policydomain
  type    = "A"
  zone_id = data.aws_route53_zone.zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
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