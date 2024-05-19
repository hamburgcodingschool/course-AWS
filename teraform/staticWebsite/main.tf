provider "aws" {
  region = "eu-central-1"
}

locals {
  zone_id = "Z0411341299NQYX9BNHA8"
  domain  = "db.seemycat.de"
  certificate_arn = "arn:aws:acm:us-east-1:604825617308:certificate/bd517cd3-8035-4b41-b668-5f967ac41fc8"

  origin_id = "db-seemycat-com-s3-origin-id"
}

# create S3 bucket to hold static files
resource "aws_s3_bucket" "s3_bucket" {
  bucket = local.domain
}

# put some demo html content into that bucket
resource "aws_s3_object" "object" {
  for_each     = fileset("html/", "*.html")
  bucket       = aws_s3_bucket.s3_bucket.bucket
  key          = each.value
  source       = "${path.module}/html/${each.value}"
  etag         = filemd5("${path.module}/html/${each.value}")
  content_type = "text/html"
}

# create a Content Delivery Network (CDN)
resource "aws_cloudfront_distribution" "s3_distribution" {
  enabled     = true
  price_class = "PriceClass_100"
  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = local.origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  default_cache_behavior {
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.origin_id
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn = local.certificate_arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  default_root_object = "index.html"
  custom_error_response {
    response_page_path = "/error.html"
    error_code         = 403
    response_code      = 404
  }
  aliases = [local.domain]
}

# configure correct access rights, so that only the CDN can acess the buckets content.
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {}
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::${local.domain}/*",
    ]
    principals {
      type = "AWS"
      identifiers = [
        aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn,
      ]
    }
  }
}
resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

# configure our own domain name system entry
resource "aws_route53_record" "route53_record" {
  zone_id = local.zone_id
  name    = local.domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}


#resource "aws_s3_bucket_website_configuration" "s3_bucket" {
#  bucket = aws_s3_bucket.s3_bucket.id
#
#  index_document {
#    suffix = "index.html"
#  }
#
#  error_document {
#    key = "error.html"
#  }
#}

output "cf_domain" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "custom_url" {
  value = "https://${aws_route53_record.route53_record.fqdn}/"
}