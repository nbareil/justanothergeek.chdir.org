provider "aws" {
  profile = "perso"
  region  = "eu-central-1"
}

provider "aws" {
  profile = "perso"
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  my_domain_name            = "3amcall.com"
  domain_name               = "blog.3amcall.com"
  blog_dnsnames             = ["blog.3amcall.com"]
  s3_origin_id              = "XXX"
  s3_bucket_logs            = "private-3amcall-logs2"
  s3_bucket                 = "public-3amcall-htdocs"
  s3_origin_access_identity = "origin-access-identity/cloudfront/E1ZTWJMWEM1KB8"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  price_class = "PriceClass_100"

  origin {
    domain_name = aws_s3_bucket.blog_htdocs.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path

    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"


  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.log_bucket.bucket_domain_name
    prefix          = "cloudfront/"
  }


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

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.https_certificate.arn
    ssl_support_method = "sni-only"
  }
}

resource "aws_acm_certificate" "https_certificate" {
  domain_name       = local.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  provider = aws.us_east_1
}

resource "aws_s3_bucket" "blog_htdocs" {
  bucket = local.s3_bucket
  acl    = "private"

  logging {
    target_bucket = aws_s3_bucket.log_bucket.id
    target_prefix = "s3/"
  }
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = local.s3_bucket_logs
  acl    = "log-delivery-write"
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.blog_htdocs.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.blog_htdocs.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "blog_htdocs_policy" {
  bucket = aws_s3_bucket.blog_htdocs.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_iam_user" "deploy" {
  name = "justanothergeekTEST-deploy"
}

resource "aws_iam_user_policy" "deploy_rw" {
  name = "deploy_policy"
  user = aws_iam_user.deploy.name

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
  handler       = "lambda-redirectLeadingSlash.handler"
  runtime       = "nodejs10.x"

  filename         = "lambda-redirectLeadingSlash.zip"
  source_code_hash = filebase64sha256("lambda-redirectLeadingSlash.zip")

  publish = true
  provider = aws.us_east_1
}

resource "aws_lambda_permission" "allow_cloudfront" {
  statement_id   = "AllowExecutionFromCloudFront"
  action         = "lambda:GetFunction"
  function_name  = aws_lambda_function.redirect_lambda.function_name
  principal      = "edgelambda.amazonaws.com"
  provider = aws.us_east_1
}

data "aws_route53_zone" "myzone" {
  name = local.my_domain_name
}

resource "aws_route53_record" "blog-a" {
  zone_id = data.aws_route53_zone.myzone.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "blog-aaaa" {
  zone_id = data.aws_route53_zone.myzone.zone_id
  name    = local.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
