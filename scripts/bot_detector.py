import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# 1. Initialize Glue Context & Spark
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'bucket_name'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Define S3 Paths (using the bucket name passed via Terraform/Arguments)
BUCKET = args['bucket_name']
INPUT_PATH = f"s3://{BUCKET}/raw/2026-02-01-*.json.gz"
OUTPUT_PATH = f"s3://{BUCKET}/gold/bot_analysis/"

print(f"Starting Spark Job. Reading data from: {INPUT_PATH}")

# 2. Read Raw GitHub JSON: GitHub Archive is line-delimited JSON
df = spark.read.json(INPUT_PATH)

# 3. Transform: Flatten and Extract Relevant Fields
events_df = df.select(
    F.col("id"),
    F.col("type").alias("event_type"),
    F.col("actor.login").alias("username"),
    F.col("created_at").cast("timestamp"),
    F.col("repo.name").alias("repo_name")
)

# 4. Bot Detection Logic: Identify known bot suffixes and high-frequency activity
window_spec = Window.partitionBy("username")

analysis_df = events_df.withColumn(
    "is_labeled_bot", 
    F.col("username").rlike("(?i)bot|automation|crawler")
).withColumn(
    "actions_in_24h", 
    F.count("id").over(window_spec)
)

# 5. Aggregate Results: gives a summary of the most active users and their "Bot Probability"
final_summary = analysis_df.groupBy("username").agg(
    F.max("is_labeled_bot").alias("is_labeled_bot"),
    F.count("id").alias("total_events"),
    F.countDistinct("repo_name").alias("distinct_repos_touched")
).orderBy(F.desc("total_events"))

# 6. Write to S3 in Parquet format
print(f"Writing results to: {OUTPUT_PATH}")
final_summary.write.mode("overwrite").parquet(OUTPUT_PATH)

job.commit()
print("Job Complete!")