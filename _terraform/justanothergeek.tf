provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

locals {
  domain_name               = "blog.3amcall.com"
  blog_dnsnames             = ["blog.3amcall.com"]
  s3_origin_id              = "XXX"
  s3_bucket_logs            = "private-3amcall-logs"
  s3_bucket                 = "public-3amcall-blog"
  //s3_origin_access_identity = "origin-access-identity/cloudfront/ABCDEFG1234567"
  s3_origin_access_identity = "origin-access-identity/cloudfront/E1ZTWJMWEM1KB8"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.blog_htdocs.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = local.s3_origin_access_identity
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"


  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.log_bucket.id
    prefix          = "cloudfront/"
  }

  aliases = local.blog_dnsnames

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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    max_ttl                = 0
    default_ttl            = 0
  }

  ordered_cache_behavior {
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["HEAD", "GET"]
    path_pattern     = "/*"
    target_origin_id = local.s3_origin_id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    // Lambda@Edge association
    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.redirect_lambda.qualified_arn
      include_body = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    iam_certificate_id = aws_acm_certificate.https_certificate.arn
  }
}

resource "aws_acm_certificate" "https_certificate" {
  domain_name       = local.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket" "blog_htdocs" {
  bucket = local.s3_bucket
  acl    = "private"

  policy = <<EOF
EOF

  logging {
    target_bucket = aws_s3_bucket.log_bucket.id
    target_prefix = "s3/"
  }
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = local.s3_bucket_logs
  acl    = "log-delivery-write"
}

resource "aws_iam_user" "deploy" {
  name = "justanothergeekTEST-deploy"
}

resource "aws_iam_user_policy" "deploy_rw" {
  name = "deploy_policy"
  user = "aws_iam_user.deploy.name"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.blog_htdocs.arn}/*",
        "${aws_s3_bucket.blog_htdocs.arn}"
      ]
    }
  ]
}
EOF
}


resource "aws_iam_role" "redirect_lambda" {
  name = "redirectLeadingSlash"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com",
        "Service": "edgelambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "redirect_lambda" {
  function_name = "lambda_function_name"
  role          = aws_iam_role.redirect_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs10.x"

  filename         = "lambda-redirectLeadingSlash.zip"
  source_code_hash = filebase64sha256("lambda-redirectLeadingSlash.zip")
}