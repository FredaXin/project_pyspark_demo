#!/bin/bash

BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# for hour in {0..23}; do
#   echo "Downloading hour $hour..."
#   curl -s "https://data.gharchive.org/2026-02-01-$hour.json.gz" | aws s3 cp - s3://$BUCKET_NAME/raw/2026-02-01-$hour.json.gz
# done

aws s3 cp scripts/bot_detector.py s3://$BUCKET_NAME/scripts/bot_detector.py