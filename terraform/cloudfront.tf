locals {
  depends_on     = [aws_s3_bucket.my-blog]
  s3_origin_id   = "${var.s3_name}-origin"
  s3_domain_name = "${aws_s3_bucket.my-blog.id}.s3-website-${var.region}.amazonaws.com"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on       = [aws_s3_bucket_website_configuration.s3_website]
  retain_on_delete = true
  origin {
    domain_name = local.s3_domain_name
    origin_id   = local.s3_origin_id
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
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
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}