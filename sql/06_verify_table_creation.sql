SELECT table_name
FROM `scm-coe-hub`.scm_analytics.INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
ORDER BY table_name;