provider "aws" {
  region = "eu-central-1"
}

locals {
  domain = "db-simple.seemycat.de"
}

# create an S3 Bucket
resource "aws_s3_bucket" "s3_bucket" {
  bucket = local.domain
}

# put some html content into that bucket
resource "aws_s3_object" "object" {
  bucket       = aws_s3_bucket.s3_bucket.bucket
  key          = "index.html"
  source       = "${path.module}/index.html"
  etag         = filemd5("${path.module}/index.html")
  content_type = "text/html"
}

# Explicitly allow public access to all elements in the bucket
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.s3_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Again explicitly allow public access via bucket policy
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::${local.domain}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}
resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

# Configure the bucket to serve its content like a static Webhosting Service
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.s3_bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

output "url" {
  value = aws_s3_bucket_website_configuration.website.website_endpoint
}
