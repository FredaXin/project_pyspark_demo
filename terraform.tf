terraform {
  # 1. Required Terraform CLI version
  required_version = ">= 1.5.0"

  # 2. Required Provider versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Allows 5.x updates, but prevents 6.0 breaking changes
    }
  }
}


provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project = "pyspark-demo"
    }
  }
}

# Data source to get current AWS account ID for IAM policies
data "aws_caller_identity" "current" {}

# 1. AWS Resource Group
resource "aws_resourcegroups_group" "pyspark_demo_group" {
  name = "pyspark-demo-group"

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": ["AWS::AllSupported"],
  "TagFilters": [
    {
      "Key": "project",
      "Values": ["pyspark-demo"]
    }
  ]
}
JSON
  }
}

# 2. S3 Bucket for Data and Scripts
resource "aws_s3_bucket" "pyspark_demo_bucket" {
  bucket = "pyspark-demo-2026-02-2201452"
}

# 3. IAM Role for Glue (Spark)
resource "aws_iam_role" "pyspark_demo_role" {
  name = "pyspark_demo_glue_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
}

# 4. Attach standard Glue and S3 policies
resource "aws_iam_role_policy_attachment" "pyspark_demo_s3" {
  role       = aws_iam_role.pyspark_demo_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "pyspark_demo_glue" {
  role       = aws_iam_role.pyspark_demo_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# 5. The Spark (Glue) Job
resource "aws_glue_job" "pyspark_demo_job" {
  name              = "pyspark_demo_bot_detector"
  role_arn          = aws_iam_role.pyspark_demo_role.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  default_arguments = {
    "--bucket_name"               = aws_s3_bucket.pyspark_demo_bucket.id
    "--job-bookmark-option"       = "job-bookmark-disable"
    "--additional-python-modules" = "pandas"
  }

  command {
    script_location = "s3://${aws_s3_bucket.pyspark_demo_bucket.bucket}/scripts/bot_detector.py"
    python_version  = "3"
  }
}

# 6. Athena Database
resource "aws_athena_database" "pyspark_demo_db" {
  name   = "pyspark_demo_db"
  bucket = aws_s3_bucket.pyspark_demo_bucket.id
}

# 7. Athena Workgroup
resource "aws_athena_workgroup" "pyspark_demo_wg" {
  name = "pyspark_demo_workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.pyspark_demo_bucket.id}/athena-results/"
    }
  }
}

# 8. Save a bookmarked query in Athena
resource "aws_athena_named_query" "top_bots_query" {
  name      = "top_bots_analysis"
  workgroup = aws_athena_workgroup.pyspark_demo_wg.name
  database  = aws_athena_database.pyspark_demo_db.name
  query     = "SELECT * FROM github_events_gold WHERE total_events > 100 ORDER BY total_events DESC LIMIT 10;"
}

# 9. IAM Role for the Glue Crawler
resource "aws_iam_role" "glue_crawler_role" {
  name = "pyspark_demo_crawler_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      },
    ]
  })
}

# 10. Attach policy so Glue Crawler can read S3 and write to CloudWatch
resource "aws_iam_role_policy_attachment" "crawler_logs" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# 11. The Glue Crawler
resource "aws_glue_crawler" "pyspark_demo_crawler" {
  database_name = aws_athena_database.pyspark_demo_db.name
  name          = "pyspark_demo_crawler"
  role          = aws_iam_role.glue_crawler_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.pyspark_demo_bucket.id}/gold/bot_analysis/"
  }
}

# 12. Policy to allow Glue Crawler to read from S3
resource "aws_iam_role_policy" "crawler_s3_policy" {
  name = "crawler_s3_policy"
  role = aws_iam_role.glue_crawler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.pyspark_demo_bucket.arn,
          "${aws_s3_bucket.pyspark_demo_bucket.arn}/*"
        ]
      }
    ]
  })
}

# 13. Policy to allow Crawler to create tables in the Database
resource "aws_iam_role_policy" "crawler_catalog_policy" {
  name = "crawler_catalog_policy"
  role = aws_iam_role.glue_crawler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:BatchCreatePartition"
        ]
        Resource = [
          # The Glue Catalog itself
          "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:catalog",
          # The Database ARN (constructed manually)
          "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:database/${aws_athena_database.pyspark_demo_db.name}",
          # The Tables inside that database
          "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:table/${aws_athena_database.pyspark_demo_db.name}/*"
        ]
      }
    ]
  })
}

# 14. Athena Query 
resource "aws_athena_named_query" "final_top_bots_query" {
  name        = "top_bots_analysis"
  workgroup   = aws_athena_workgroup.pyspark_demo_wg.name
  database    = aws_athena_database.pyspark_demo_db.name
  description = "Calculates bot activity density for users with > 50 events."

  query = file("${path.module}/queries/top_bots.sql")
}
