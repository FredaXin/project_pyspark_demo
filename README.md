# The Rise of the AI Agent: A Data-Driven Analysis of GitHub Automation (Using PySpark, AWS Glue, and Amazon Athena)

Who (or what) is responsible for the most activity on GitHub nowadays? Traditional bots, such as GitHub’s Dependabot, have long contributed to a large portion of GitHub events. But recently, AI-native bots have become increasingly prevalent across the open-source landscape.

In this project, I built an ETL pipeline to process and analyze GitHub activity, providing a data-driven look into this new age of automation. This project demonstrates a serverless architecture that identifies automated signatures by leveraging PySpark for high-scale data processing, AWS Glue for automated schema management, and Amazon Athena for SQL-based analytics.

## Architecture
**Storage**: S3 (Raw, Gold, and Athena Results)

**Processing**: AWS Glue (PySpark ETL)

**Orchestration**: AWS Glue Crawler (Schema Inference)

**Analysis**: Amazon Athena (Presto SQL)

**IaC**: Terraform

##  PySpark Implementation

* **Feature Engineering:** Implements a custom **Activity Density** metric to quantify automation signatures:
    
    $$Activity\ Density = \frac{Total\ Events}{Distinct\ Repos\ Touched}$$
    
    * **The Logic:** This ratio distinguishes between human developers (who typically exhibit a lower, more distributed density) and CI/CD pipelines or scrapers (which exhibit extreme density by targeting specific repos with high-frequency events).
* **Storage Optimization:** creates data output in **Parquet** format. Comparing to the row-based JSON, this columnar storage reduces S3 storage costs and improves Athena query performance. 

## Analysis Results at a Glance
As shown in the Athena query output, based on the Activity Density (events per repository), we can categorize these bots into at least two distinct "species" of automation:

1. The "AI Co-Engineers" (Density: 4.8 – 9.0): These are GenAI-type bots. They have a higher density because they don't just "ping" a repository; they perform "deep work"—like reading, writing, and reviewing code.

    Examples: Copilot (8.9), CodeRabbitAI (5.8), Gemini-Code-Assist (5.1), and Lovable-Dev (4.8).

2. The "Maintainer Bots" (Density: 3.5 – 6.6): These are the "old-fashioned" bots of GitHub. They follow strict, deterministic rules to keep the lights on.

    Examples: Dependabot (6.5), GitHub Actions (3.5), and Renovate (3.7).

Key Finding: AI-Native bots exhibit a specific activity signature: they maintain a higher Activity Density (typically 5.0+) compared to traditional CI/CD bots. 

![Athena_Output](/images/aws_athena_output.png)

## Usage & Deployment
1. Provision Infrastructure
```
terraform init
terraform apply
```

2. Execute Pipeline

    Run Glue Job: `pyspark_demo_bot_detector` (Processes raw JSON to Parquet).
    Run Crawler: `pyspark_demo_crawler` (Updates the Data Catalog).

3. Query Results
Access the pre-provisioned SQL query in Amazon Athena. 

## Disclaimer & Data Source
The data analyzed in this project is from the [GitHub Archive](https://data.gharchive.org), which records the public GitHub timeline.

Please note that this analysis is based on results from a single day (February 21, 2026). While these findings offer a snapshot of current activity, they do not represent a long-term study. To see a clearer trend regarding the "takeover" of AI bots, we need further research and a larger dataset of a longer time period.