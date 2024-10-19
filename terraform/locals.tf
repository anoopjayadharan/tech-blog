locals {
  s3_origin_id   = "${var.s3_name}-origin"
  s3_domain_name = aws_s3_bucket.my-blog.bucket_regional_domain_name
  blog_domain    = "ajworkspace.cloudtalents.io"
}