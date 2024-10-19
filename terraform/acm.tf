resource "aws_acm_certificate" "blog_cert" {
  domain_name       = local.blog_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}