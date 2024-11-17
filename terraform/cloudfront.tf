resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on       = [aws_s3_bucket.my-blog]
  retain_on_delete = true
  origin {
    domain_name              = local.s3_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.S3_OAC.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["ajworkspace.cloudtalents.io"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.URI_Add.arn
    }

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.blog_cert.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
resource "aws_cloudfront_origin_access_control" "S3_OAC" {
  name                              = aws_s3_bucket.my-blog.id
  description                       = "OAC for S3 bucket ${aws_s3_bucket.my-blog.id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_function" "URI_Add" {
  name    = "custom_function"
  runtime = "cloudfront-js-2.0"
  comment = "Add index.html to request URLs without a file name"
  publish = true
  code    = file("code/function.js")
}
resource "aws_s3_bucket_policy" "CF_S3_Policy" {
  bucket = aws_s3_bucket.my-blog.id
  policy = <<EOT
  {
        "Version": "2008-10-17",
        "Id": "PolicyForCloudFrontPrivateContent",
        "Statement": [
            {
                "Sid": "AllowCloudFrontServicePrincipal",
                "Effect": "Allow",
                "Principal": {
                    "Service": "cloudfront.amazonaws.com"
                },
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::${aws_s3_bucket.my-blog.id}/*",
                "Condition": {
                    "StringEquals": {
                      "AWS:SourceArn": "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.s3_distribution.id}"
                    }
                }
            }
        ]
      }
      EOT
}