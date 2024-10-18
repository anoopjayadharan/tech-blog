output "s3_bucket" {
    value = aws_s3_bucket.my-blog.id
}
output "cloudFront_ID" {
    value = aws_cloudfront_distribution.s3_distribution.id 
}
output "cloudFront_domain_name" {
    value = aws_cloudfront_distribution.s3_distribution.domain_name 
}