SELECT 
    username, 
    total_events, 
    distinct_repos_touched,
    is_labeled_bot,
    (CAST(total_events AS DOUBLE) / CAST(distinct_repos_touched AS DOUBLE)) as activity_density
FROM 
    "pyspark_demo_db"."bot_analysis"
WHERE 
    total_events > 50
ORDER BY 
    total_events DESC 
LIMIT 10;