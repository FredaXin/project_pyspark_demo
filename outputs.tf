output "s3_bucket_name" {
  description = "The name of the S3 bucket created for data and scripts"
  value       = aws_s3_bucket.pyspark_demo_bucket.id
}

output "glue_job_name" {
  description = "The name of the Spark/Glue job"
  value       = aws_glue_job.pyspark_demo_job.id
}

output "glue_role_arn" {
  description = "The ARN of the IAM role used by Glue"
  value       = aws_iam_role.pyspark_demo_role.arn
}

output "resource_group_arn" {
  description = "The ARN of the Resource Group managing these resources"
  value       = aws_resourcegroups_group.pyspark_demo_group.arn
}

output "script_upload_command" {
  description = "Helper command to upload your Spark script once written"
  value       = "aws s3 cp bot_detector.py s3://${aws_s3_bucket.pyspark_demo_bucket.id}/scripts/bot_detector.py"
}

output "data_upload_command" {
  description = "Helper command to upload your GH Archive data"
  value       = "aws s3 cp . s3://${aws_s3_bucket.pyspark_demo_bucket.id}/raw/ --recursive --exclude '*' --include '2026-02-01-*.json.gz'"
}
