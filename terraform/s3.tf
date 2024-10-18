resource "random_id" "object" {
  byte_length = 4
}
resource "aws_s3_bucket" "my-blog" {
  bucket = "${var.s3_name}-${lower(random_id.object.id)}"
}
resource "aws_s3_bucket_website_configuration" "s3_website" {
  bucket = aws_s3_bucket.my-blog.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }

}
resource "aws_s3_bucket_public_access_block" "s3_public_access" {
  bucket = aws_s3_bucket.my-blog.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "my_blog_policy" {
  bucket     = aws_s3_bucket.my-blog.id
  depends_on = [aws_s3_bucket_public_access_block.s3_public_access]
  policy     = <<EOT
  {
    "Version": "2012-10-17",
    "Id": "Policy1728560112286",
    "Statement": [
        {
            "Sid": "Allow_S3_Access",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.my-blog.id}/*"
        }
    ]
}
EOT
}
