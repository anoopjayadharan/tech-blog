resource "aws_acm_certificate" "blog_cert" {
  provider = aws.us-east-1
  domain_name       = local.blog_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}