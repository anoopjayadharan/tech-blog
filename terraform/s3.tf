resource "random_id" "object" {
  byte_length = 4
}
resource "aws_s3_bucket" "my-blog" {
  bucket = "${var.s3_name}-${lower(random_id.object.id)}"
  force_destroy = true
}